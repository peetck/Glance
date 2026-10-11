# Glance

A macOS menu bar app that shows a real-time crypto price, like RunCat or Stats.
You enter symbols in TradingView format (`BTCUSDC.P` = Binance USDⓈ-M perpetual, `BTCUSDT` = spot).

## Run

```sh
swift run                 # dev (quick iterate)
./scripts/bundle.sh       # → build/Glance.app (menu-bar only, no Dock icon)
open build/Glance.app
```

Needs only the Xcode Command Line Tools and macOS 14 or later. If you install full Xcode, you can open `Package.swift` in it.

## Layout

```
Sources/Glance/
  App/GlanceApp.swift           MenuBarExtra scene + accessory activation policy
  Models/Instrument.swift       TradingView symbol parsing (BTCUSDC.P, BINANCE:ETHUSDT.P, BTC/USDC.P)
  Models/Ticker.swift           Binance miniTicker decoding, connection status
  Services/BinanceStream.swift  WebSocket client with exponential-backoff reconnect
  Services/TickerStore.swift    App state, persistence (UserDefaults), price formatting
  Views/MenuContentView.swift   Dropdown: price, 24h stats, symbol input, favorites
```

## Roadmap

See the implementation plan below. Phase 1 is done.

1. **MVP (done):** one symbol in the menu bar, Binance spot and perp over WebSocket, auto-reconnect, favorites, persistence.
2. **Symbol search:** fetch `exchangeInfo` from the spot and futures REST APIs, cache it, and fuzzy-search it with autocomplete. Use `tickSize` for exact decimal places.
3. **Menu bar polish:** green/red colored text (render an `NSAttributedString` through `NSStatusItem`, because `MenuBarExtra` labels draw as monochrome templates), an option to flash on price change, and display modes (price, price and %, compact).
4. **Multi-ticker:** rotate symbols, or show 2–3 at once by combining streams (`/stream?streams=a@miniTicker/b@miniTicker`).
5. **More exchanges:** a `PriceProvider` protocol with Bybit, OKX, Hyperliquid, and Coinbase implementations. Parse `EXCHANGE:SYMBOL` prefixes.
6. **Sparkline and alerts:** a mini chart in the dropdown from `@kline_1m`, and price-cross alerts through `UserNotifications`.
7. **Ship it:** Settings window, launch at login (`SMAppService.mainApp`), app icon, Developer ID signing and notarization, Sparkle auto-updates.
