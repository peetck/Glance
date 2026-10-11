import Foundation
import SwiftUI

@MainActor
final class TickerStore: ObservableObject {
    @Published private(set) var instrument: Instrument
    @Published private(set) var ticker: MiniTicker?
    @Published private(set) var status: ConnectionStatus = .connecting
    @Published private(set) var favorites: [Instrument]

    private let stream = BinanceStream()
    private let defaults = UserDefaults.standard

    init() {
        instrument = Self.load(Instrument.self, key: "instrument") ?? .default
        favorites = Self.load([Instrument].self, key: "favorites") ?? [
            .default,
            Instrument(symbol: "ETHUSDC", market: .perp),
            Instrument(symbol: "SOLUSDT", market: .spot),
        ]
        connect()
    }

    var menuBarTitle: String {
        guard let ticker else { return "\(instrument.tvSymbol) …" }
        let arrow = ticker.changePercent >= 0 ? "▲" : "▼"
        return "\(Self.baseAsset(instrument.symbol)) \(PriceFormatter.price(ticker.close)) \(arrow)"
    }

    func select(_ instrument: Instrument) {
        guard instrument != self.instrument else { return }
        self.instrument = instrument
        ticker = nil
        save(instrument, key: "instrument")
        connect()
    }

    func toggleFavorite(_ instrument: Instrument) {
        if let i = favorites.firstIndex(of: instrument) {
            favorites.remove(at: i)
        } else {
            favorites.append(instrument)
        }
        save(favorites, key: "favorites")
    }

    private func connect() {
        stream.start(
            instrument,
            onTicker: { [weak self] in self?.ticker = $0 },
            onStatus: { [weak self] in self?.status = $0 }
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
    static func price(_ value: Double) -> String {
        let decimals: Int
        switch abs(value) {
        case 1000...: decimals = 1
        case 1..<1000: decimals = 3
        default: decimals = 6
        }
        return value.formatted(.number.precision(.fractionLength(decimals)).grouping(.automatic))
    }

    static func percent(_ value: Double) -> String {
        (value >= 0 ? "+" : "") + value.formatted(.number.precision(.fractionLength(2))) + "%"
    }

    static func compact(_ value: Double) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(2)))
    }
}
