import Foundation

/// A market data source. Only exchanges with a `MarketDataProvider` (see `Providers`) are
/// usable; the rest are listed so the UI can show them as coming soon.
enum Exchange: String, Codable, CaseIterable, Identifiable {
    case binance
    case bybit
    case okx
    case hyperliquid
    case coinbase

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .binance: "Binance"
        case .bybit: "Bybit"
        case .okx: "OKX"
        case .hyperliquid: "Hyperliquid"
        case .coinbase: "Coinbase"
        }
    }

    /// TradingView exchange prefix, as in `BYBIT:BTCUSDT.P`.
    var tvPrefix: String { rawValue.uppercased() }

    var isAvailable: Bool { Providers.provider(for: self) != nil }

    init?(tvPrefix: String) {
        self.init(rawValue: tvPrefix.lowercased())
    }

    static let `default` = Exchange.binance
}
