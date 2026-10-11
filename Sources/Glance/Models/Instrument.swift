import Foundation

enum Market: String, Codable, CaseIterable {
    case spot
    case perp // Binance USDⓈ-M perpetual futures
}

/// A tradable symbol, parsed from TradingView-style notation:
/// `BTCUSDC.P` → perp, `BTCUSDT` → spot, `BINANCE:ETHUSDT.P` / `BTC/USDC.P` also accepted.
struct Instrument: Codable, Hashable, Identifiable {
    let symbol: String
    let market: Market

    var id: String { tvSymbol }
    var tvSymbol: String { market == .perp ? "\(symbol).P" : symbol }

    init(symbol: String, market: Market) {
        self.symbol = symbol.uppercased()
        self.market = market
    }

    init?(tvSymbol raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let colon = s.lastIndex(of: ":") { s = String(s[s.index(after: colon)...]) }
        s = s.replacingOccurrences(of: "/", with: "")
        var market = Market.spot
        if s.hasSuffix(".P") {
            market = .perp
            s.removeLast(2)
        }
        guard !s.isEmpty, s.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        self.init(symbol: s, market: market)
    }

    static let `default` = Instrument(symbol: "BTCUSDC", market: .perp)
}
