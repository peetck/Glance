import Foundation

/// 24h rolling price stats for one instrument, common to all exchanges.
struct MiniTicker {
    let symbol: String
    let close: Double
    let open: Double
    let high: Double
    let low: Double
    let quoteVolume: Double

    var changePercent: Double { open == 0 ? 0 : (close - open) / open * 100 }
}

/// Decodes Binance's `<symbol>@miniTicker` payload (same shape for spot and futures).
/// Other providers build `MiniTicker` with the memberwise initializer.
extension MiniTicker: Decodable {
    enum CodingKeys: String, CodingKey {
        case symbol = "s", close = "c", open = "o", high = "h", low = "l", quoteVolume = "q"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func num(_ key: CodingKeys) throws -> Double {
            let str = try c.decode(String.self, forKey: key)
            guard let v = Double(str) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Not a number: \(str)")
            }
            return v
        }
        self.init(
            symbol: try c.decode(String.self, forKey: .symbol),
            close: try num(.close),
            open: try num(.open),
            high: try num(.high),
            low: try num(.low),
            quoteVolume: try num(.quoteVolume)
        )
    }
}

enum ConnectionStatus: Equatable {
    case connecting
    case live
    case reconnecting(in: Int)
    /// No provider for the instrument's exchange yet.
    case unsupported
}
