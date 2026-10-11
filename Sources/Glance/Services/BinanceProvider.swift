import Foundation

struct BinanceProvider: MarketDataProvider {
    let exchange = Exchange.binance

    func makeStream() -> TickerStream { BinanceStream() }

    /// Uses the 24h ticker endpoints rather than `exchangeInfo`: ~1.3 MB combined versus ~7 MB,
    /// and they include a popularity score.
    func fetchSymbols() async throws -> [SymbolEntry] {
        async let spot = Self.fetch("https://api.binance.com/api/v3/ticker/24hr?type=MINI", market: .spot)
        async let perp = Self.fetch("https://fapi.binance.com/fapi/v1/ticker/24hr", market: .perp)
        return try await spot + perp
    }

    private static func fetch(_ url: String, market: Market) async throws -> [SymbolEntry] {
        let (data, response) = try await URLSession.shared.data(from: URL(string: url)!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let now = Date().timeIntervalSince1970 * 1000
        return try JSONDecoder().decode([RawTicker].self, from: data).compactMap { t in
            // The spot endpoint also returns delisted symbols with no recent trades.
            // Dated futures (BTCUSDT_261225) contain "_" and aren't supported.
            guard let count = t.count, count > 0,
                  now - t.closeTime < 86_400_000,
                  t.symbol.allSatisfy({ $0.isLetter || $0.isNumber }),
                  let last = Double(t.lastPrice), let open = Double(t.openPrice)
            else { return nil }
            return SymbolEntry(
                instrument: Instrument(exchange: .binance, symbol: t.symbol, market: market),
                lastPrice: last,
                changePercent: open == 0 ? 0 : (last - open) / open * 100,
                trades: count
            )
        }
    }
}

private struct RawTicker: Decodable {
    let symbol: String
    let lastPrice: String
    let openPrice: String
    let count: Int?
    let closeTime: Double
}
