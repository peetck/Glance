import Foundation

enum Market: String, Codable, CaseIterable {
    case spot
    case perp // USDⓈ-M / linear perpetual futures
}

/// A tradable symbol on one exchange, parsed from TradingView-style notation:
/// `BTCUSDC.P` → perp, `BTCUSDT` → spot, `BINANCE:ETHUSDT.P` / `BTC/USDC.P` also accepted.
struct Instrument: Codable, Hashable, Identifiable {
    let exchange: Exchange
    let symbol: String
    let market: Market

    var id: String { "\(exchange.tvPrefix):\(tvSymbol)" }
    var tvSymbol: String { market == .perp ? "\(symbol).P" : symbol }

    init(exchange: Exchange = .default, symbol: String, market: Market) {
        self.exchange = exchange
        self.symbol = symbol.uppercased()
        self.market = market
    }

    /// An `EXCHANGE:` prefix wins over `defaultExchange`; an unknown prefix fails to parse.
    init?(tvSymbol raw: String, defaultExchange: Exchange = .default) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var exchange = defaultExchange
        if let colon = s.lastIndex(of: ":") {
            guard let prefixed = Exchange(tvPrefix: String(s[..<colon])) else { return nil }
            exchange = prefixed
            s = String(s[s.index(after: colon)...])
        }
        s = s.replacingOccurrences(of: "/", with: "")
        var market = Market.spot
        if s.hasSuffix(".P") {
            market = .perp
            s.removeLast(2)
        }
        guard !s.isEmpty, s.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        self.init(exchange: exchange, symbol: s, market: market)
    }

    // Instruments saved before multi-exchange support have no `exchange`; they were all Binance.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            exchange: try c.decodeIfPresent(Exchange.self, forKey: .exchange) ?? .binance,
            symbol: try c.decode(String.self, forKey: .symbol),
            market: try c.decode(Market.self, forKey: .market)
        )
    }

    static let `default` = Instrument(symbol: "BTCUSDC", market: .perp)
}
