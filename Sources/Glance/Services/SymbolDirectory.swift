import Foundation

/// A tradable symbol from an exchange's symbol list, used for search.
struct SymbolEntry: Identifiable, Hashable {
    let instrument: Instrument
    let lastPrice: Double
    let changePercent: Double
    /// 24h trade count. Used as a popularity score because, unlike quote volume, it doesn't
    /// depend on the quote currency (BTCTRY volume is in lira).
    let trades: Int

    var id: String { instrument.id }
}

/// Caches each exchange's symbol list (from its `MarketDataProvider`) for a few minutes.
@MainActor
final class SymbolDirectory {
    private static let maxAge: TimeInterval = 5 * 60

    private var cache: [Exchange: (entries: [SymbolEntry], loadedAt: Date)] = [:]
    private var loading: [Exchange: Task<[SymbolEntry], Error>] = [:]

    func cached(_ exchange: Exchange) -> [SymbolEntry]? { cache[exchange]?.entries }

    func entries(for exchange: Exchange) async throws -> [SymbolEntry] {
        if let hit = cache[exchange], Date().timeIntervalSince(hit.loadedAt) < Self.maxAge { return hit.entries }
        if let task = loading[exchange] { return try await task.value }
        guard let provider = Providers.provider(for: exchange) else { throw URLError(.unsupportedURL) }
        let task = Task { try await provider.fetchSymbols() }
        loading[exchange] = task
        defer { loading[exchange] = nil }
        do {
            let entries = try await task.value
            cache[exchange] = (entries, Date())
            return entries
        } catch {
            // Keep serving a stale list if there is one; search still works offline.
            if let stale = cache[exchange] { return stale.entries }
            throw error
        }
    }

    /// Ranks matches: exact symbol in the typed market, exact symbol, prefix, then substring;
    /// ties go to the most traded symbol.
    nonisolated static func search(_ raw: String, in entries: [SymbolEntry], limit: Int = 8) -> [SymbolEntry] {
        var q = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let colon = q.lastIndex(of: ":") { q = String(q[q.index(after: colon)...]) }
        q = q.replacingOccurrences(of: "/", with: "").replacingOccurrences(of: " ", with: "")
        var market: Market?
        if q.hasSuffix(".P") {
            market = .perp
            q.removeLast(2)
        } else if q.hasSuffix(".") {
            q.removeLast() // halfway through typing ".P"
        }
        guard !q.isEmpty else { return [] }

        let scored = entries.compactMap { e -> (tier: Int, entry: SymbolEntry)? in
            if let market, e.instrument.market != market { return nil }
            let s = e.instrument.symbol
            let tier: Int
            if s == q {
                // No ".P" means spot in TradingView notation.
                tier = e.instrument.market == (market ?? .spot) ? 0 : 1
            } else if s.hasPrefix(q) {
                tier = 2
            } else if s.contains(q) {
                tier = 3
            } else {
                return nil
            }
            return (tier, e)
        }
        return scored
            .sorted { $0.tier != $1.tier ? $0.tier < $1.tier : $0.entry.trades > $1.entry.trades }
            .prefix(limit)
            .map(\.entry)
    }
}

/// Search-as-you-type state for the symbol field: debounces input, then filters the selected
/// exchange's symbol list.
@MainActor
final class SymbolSearch: ObservableObject {
    enum State: Equatable { case idle, loading, failed, unsupported }

    static let debounce: Duration = .milliseconds(250)

    @Published var query = "" {
        didSet { if query != oldValue { schedule() } }
    }
    @Published var exchange: Exchange = .default {
        didSet { if exchange != oldValue { schedule() } }
    }
    @Published private(set) var results: [SymbolEntry] = []
    @Published private(set) var state: State = .idle
    @Published var inputError = false

    private let directory: SymbolDirectory
    private var pending: Task<Void, Never>?

    init(directory: SymbolDirectory? = nil) {
        self.directory = directory ?? SymbolDirectory()
    }

    /// The instrument Enter should add: what was typed if it's a real symbol (or the list is
    /// unavailable), otherwise the best match.
    func bestMatch() -> Instrument? {
        guard exchange.isAvailable else { return nil }
        let typed = Instrument(tvSymbol: query, defaultExchange: exchange)
        guard let entries = directory.cached(exchange) else { return typed }
        if let typed, entries.contains(where: { $0.instrument == typed }) { return typed }
        return SymbolDirectory.search(query, in: entries, limit: 1).first?.instrument
    }

    func clear() {
        pending?.cancel()
        query = ""
        results = []
        inputError = false
    }

    private func schedule() {
        pending?.cancel()
        inputError = false
        // Typing a TradingView prefix (BYBIT:...) switches the source picker.
        if let colon = query.lastIndex(of: ":"),
           let typed = Exchange(tvPrefix: query[..<colon].trimmingCharacters(in: .whitespaces)),
           typed != exchange {
            exchange = typed // re-enters schedule() via didSet
            return
        }
        let q = query
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            state = .idle
            return
        }
        guard exchange.isAvailable else {
            results = []
            state = .unsupported
            return
        }
        let exchange = exchange
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.run(q, on: exchange)
        }
    }

    private func run(_ q: String, on exchange: Exchange) async {
        if directory.cached(exchange) == nil { state = .loading }
        do {
            let entries = try await directory.entries(for: exchange)
            guard q == query, exchange == self.exchange else { return } // input changed while loading
            results = SymbolDirectory.search(q, in: entries)
            state = .idle
        } catch {
            guard q == query, exchange == self.exchange else { return }
            results = []
            state = .failed
        }
    }
}
