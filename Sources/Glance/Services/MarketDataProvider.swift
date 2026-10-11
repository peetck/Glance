import Foundation

/// Live price updates for one instrument. Implementations reconnect on their own and report
/// progress through `onStatus`.
protocol TickerStream: AnyObject {
    func start(
        _ instrument: Instrument,
        onTicker: @escaping @MainActor (MiniTicker) -> Void,
        onStatus: @escaping @MainActor (ConnectionStatus) -> Void
    )
    func stop()
}

/// Everything the app needs from one exchange. To add an exchange, implement this and
/// register it in `Providers.provider(for:)`; the UI picks it up automatically.
protocol MarketDataProvider: Sendable {
    var exchange: Exchange { get }
    func makeStream() -> TickerStream
    /// All currently trading spot and perp symbols, for search.
    func fetchSymbols() async throws -> [SymbolEntry]
}

enum Providers {
    static func provider(for exchange: Exchange) -> MarketDataProvider? {
        switch exchange {
        case .binance: BinanceProvider()
        case .bybit, .okx, .hyperliquid, .coinbase: nil
        }
    }
}
