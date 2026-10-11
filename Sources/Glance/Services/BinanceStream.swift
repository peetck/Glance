import Foundation

/// Streams `miniTicker` updates for one instrument over a Binance WebSocket,
/// reconnecting with exponential backoff.
final class BinanceStream: TickerStream {
    private var task: Task<Void, Never>?
    private static let silenceTimeout: TimeInterval = 15

    static func url(for instrument: Instrument) -> URL {
        let stream = "\(instrument.symbol.lowercased())@miniTicker"
        switch instrument.market {
        case .spot: return URL(string: "wss://stream.binance.com:9443/ws/\(stream)")!
        // USDⓈ-M market streams moved under /market; the legacy /ws path still accepts
        // the connection but never sends data.
        case .perp: return URL(string: "wss://fstream.binance.com/market/ws/\(stream)")!
        }
    }

    func start(
        _ instrument: Instrument,
        onTicker: @escaping @MainActor (MiniTicker) -> Void,
        onStatus: @escaping @MainActor (ConnectionStatus) -> Void
    ) {
        stop()
        let url = Self.url(for: instrument)
        task = Task {
            var backoff = 1
            while !Task.isCancelled {
                await onStatus(.connecting)
                let ws = URLSession.shared.webSocketTask(with: url)
                ws.resume()
                let activity = Activity()
                // Watchdog: a socket that is open but silent counts as dead, so it reconnects.
                let watchdog = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(5))
                        if activity.secondsSinceLast > Self.silenceTimeout {
                            ws.cancel(with: .goingAway, reason: nil)
                            return
                        }
                    }
                }
                await withTaskCancellationHandler {
                    do {
                        while !Task.isCancelled {
                            let message = try await ws.receive()
                            activity.touch()
                            guard case .string(let text) = message,
                                  let ticker = try? JSONDecoder().decode(MiniTicker.self, from: Data(text.utf8))
                            else { continue }
                            backoff = 1
                            await onStatus(.live)
                            await onTicker(ticker)
                        }
                    } catch {
                        // Socket closed or errored; fall through to reconnect.
                    }
                } onCancel: {
                    ws.cancel(with: .goingAway, reason: nil)
                }
                watchdog.cancel()
                ws.cancel(with: .goingAway, reason: nil)
                guard !Task.isCancelled else { return }
                await onStatus(.reconnecting(in: backoff))
                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 2, 30)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

/// Thread-safe timestamp of the last received message.
private final class Activity: @unchecked Sendable {
    private let lock = NSLock()
    private var last = Date()

    func touch() { lock.withLock { last = Date() } }
    var secondsSinceLast: TimeInterval { lock.withLock { Date().timeIntervalSince(last) } }
}
