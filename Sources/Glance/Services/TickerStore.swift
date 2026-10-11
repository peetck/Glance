import Foundation
import SwiftUI

@MainActor
final class TickerStore: ObservableObject {
    static let maxInstruments = 5

    /// Symbols shown at the same time, in menu bar order.
    @Published private(set) var instruments: [Instrument]
    @Published private(set) var tickers: [Instrument: MiniTicker] = [:]
    @Published private(set) var statuses: [Instrument: ConnectionStatus] = [:]
    @Published private(set) var favorites: [Instrument]

    /// Lives on the store so the symbol list cache survives closing the dropdown.
    let search = SymbolSearch()

    private var streams: [Instrument: TickerStream] = [:]
    private let defaults = UserDefaults.standard

    init() {
        if let saved = Self.load([Instrument].self, key: "instruments") {
            // An empty list is valid: the user chose to show no symbols.
            instruments = Array(saved.prefix(Self.maxInstruments))
        } else {
            // Migrate the single-symbol setting from earlier versions.
            instruments = [Self.load(Instrument.self, key: "instrument") ?? .default]
        }
        favorites = Self.load([Instrument].self, key: "favorites") ?? [
            .default,
            Instrument(symbol: "ETHUSDC", market: .perp),
            Instrument(symbol: "SOLUSDT", market: .spot),
        ]
        instruments.forEach(connect)
    }

    var isFull: Bool { instruments.count >= Self.maxInstruments }

    var menuBarTitle: String {
        instruments.map { inst in
            guard let ticker = tickers[inst] else { return "\(Self.baseAsset(inst.symbol)) …" }
            let arrow = ticker.changePercent >= 0 ? "▲" : "▼"
            return "\(Self.baseAsset(inst.symbol)) \(PriceFormatter.price(ticker.close)) \(arrow)"
        }
        .joined(separator: "  ")
    }

    func contains(_ instrument: Instrument) -> Bool { instruments.contains(instrument) }

    /// Adds a symbol to the display. Returns false if it is already shown or the limit is reached.
    @discardableResult
    func add(_ instrument: Instrument) -> Bool {
        guard !contains(instrument), !isFull else { return false }
        instruments.append(instrument)
        save(instruments, key: "instruments")
        connect(instrument)
        return true
    }

    func remove(_ instrument: Instrument) {
        guard let i = instruments.firstIndex(of: instrument) else { return }
        instruments.remove(at: i)
        streams.removeValue(forKey: instrument)?.stop()
        tickers[instrument] = nil
        statuses[instrument] = nil
        save(instruments, key: "instruments")
    }

    func toggle(_ instrument: Instrument) {
        if contains(instrument) { remove(instrument) } else { add(instrument) }
    }

    func move(_ instrument: Instrument, by offset: Int) {
        guard let i = instruments.firstIndex(of: instrument) else { return }
        let j = i + offset
        guard instruments.indices.contains(j) else { return }
        instruments.swapAt(i, j)
        save(instruments, key: "instruments")
    }

    func toggleFavorite(_ instrument: Instrument) {
        if let i = favorites.firstIndex(of: instrument) {
            favorites.remove(at: i)
        } else {
            favorites.append(instrument)
        }
        save(favorites, key: "favorites")
    }

    /// Moves a favorite into `target`'s slot (drag and drop in the favorites grid).
    func moveFavorite(_ instrument: Instrument, to target: Instrument) {
        guard instrument != target,
              let from = favorites.firstIndex(of: instrument),
              let to = favorites.firstIndex(of: target)
        else { return }
        favorites.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        save(favorites, key: "favorites")
    }

    func moveFavorite(_ instrument: Instrument, by offset: Int) {
        guard let i = favorites.firstIndex(of: instrument), favorites.indices.contains(i + offset) else { return }
        moveFavorite(instrument, to: favorites[i + offset])
    }

    private func connect(_ instrument: Instrument) {
        guard let provider = Providers.provider(for: instrument.exchange) else {
            statuses[instrument] = .unsupported
            return
        }
        let stream = provider.makeStream()
        streams[instrument] = stream
        statuses[instrument] = .connecting
        stream.start(
            instrument,
            onTicker: { [weak self] in
                guard let self, self.streams[instrument] === stream else { return }
                self.tickers[instrument] = $0
            },
            onStatus: { [weak self] in
                guard let self, self.streams[instrument] === stream else { return }
                self.statuses[instrument] = $0
            }
        )
    }

    /// Strips common quote currencies for a compact menu bar label (BTCUSDC → BTC).
    static func baseAsset(_ symbol: String) -> String {
        for quote in ["USDC", "USDT", "FDUSD", "BUSD", "USD", "BTC", "ETH"] where symbol.hasSuffix(quote) && symbol.count > quote.count {
            return String(symbol.dropLast(quote.count))
        }
        return symbol
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}

enum PriceFormatter {
    /// Two decimals (62,431.50). Below 1, two decimals would round small coins (PEPE ≈ 0.00001)
    /// to 0.00, so those keep 4 significant digits instead.
    static func price(_ value: Double) -> String {
        if value == 0 || abs(value) >= 1 {
            return value.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
        }
        return value.formatted(.number.precision(.significantDigits(4)))
    }

    static func percent(_ value: Double) -> String {
        (value >= 0 ? "+" : "") + value.formatted(.number.precision(.fractionLength(2))) + "%"
    }

    static func compact(_ value: Double) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(2)))
    }
}
