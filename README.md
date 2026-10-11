<p align="center">
  <img src="assets/glance-icon.png" width="160" alt="Glance icon: a lopsided emoji glancing up at the menu bar">
</p>

<h1 align="center">Glance</h1>

<p align="center">Real-time crypto prices in your macOS menu bar. Just glance up.</p>

<p align="center">
  <a href="https://github.com/peetck/Glance/releases/latest"><b>Download the latest release</b></a>
  ·
  <a href="LICENSE">MIT License</a>
</p>

Glance is a small menu bar app, like RunCat or Stats, that streams live prices from Binance.

## Features

- **Up to 5 tickers at once,** side by side in the menu bar (`BTC 62,431.5 ▲  ETH 2,412.300 ▼`). You can also show none; the menu bar then shows a small icon.
- **Search as you type** across every trading Binance spot and perp symbol, ranked by popularity. No button press needed.
- **TradingView notation:** `BTCUSDC.P` = USDⓈ-M perpetual, `BTCUSDT` = spot. `BINANCE:ETHUSDT.P` and `BTC/USDC.P` also work.
- **Favorites:** star a shown symbol, then click its chip to show or hide it, and drag chips to reorder.
- **Per-ticker details** in the dropdown: price, 24h change, high, low, volume, and connection status. You can reorder tickers in the menu bar.
- **Auto-reconnect** with exponential backoff and a watchdog for silent sockets.
- **Auto-update:** checks GitHub Releases once a day and updates in place with one click (⚙︎ → Check for Updates…).
- **Ready for more exchanges:** a source picker and provider protocol are in place. Bybit, OKX, Hyperliquid, and Coinbase are listed as coming soon.

## Install

Requires macOS 14 (Sonoma) or later. Works on Apple silicon and Intel Macs.

1. Download `Glance-vX.Y.Z.dmg` from the [latest release](https://github.com/peetck/Glance/releases/latest) and open it.
2. Drag **Glance** onto the **Applications** shortcut in the window, then eject the disk image.
3. Open Glance from Applications. It appears in the menu bar, not the Dock.

**"Glance can't be opened because Apple cannot check it for malicious software."**
Glance isn't signed with a paid Apple Developer ID yet, so macOS blocks it the first time. Pick one:

- Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the Glance message. Then open the app again.
- Or run this once in Terminal:

  ```sh
  xattr -dr com.apple.quarantine /Applications/Glance.app
  ```

If you'd rather not trust a downloaded binary, build it yourself (below). It takes about a minute.

To quit, open the dropdown and click **Quit** (or press ⌘Q while it's open).

## Build from source

```sh
git clone https://github.com/peetck/Glance.git
cd Glance
swift run                 # dev (quick iterate)
./scripts/bundle.sh       # → build/Glance.app (universal, with icon; menu-bar only, no Dock icon)
open build/Glance.app
./scripts/dmg.sh          # optional: → build/Glance.dmg, like the release download
```

Needs only the Xcode Command Line Tools (`xcode-select --install`) and macOS 14 or later. If you install full Xcode, you can open `Package.swift` in it.

Want to contribute? See [CONTRIBUTING.md](CONTRIBUTING.md). Working on this with an AI agent? Read [AGENTS.md](AGENTS.md) first. It covers the toolchain limits (no Swift macros) and how to add an exchange.

## Layout

```
Sources/Glance/
  App/GlanceApp.swift           MenuBarExtra scene + accessory activation policy
  Models/Exchange.swift         Data sources (Binance live; others listed as coming soon)
  Models/Instrument.swift       TradingView symbol parsing (BTCUSDC.P, BINANCE:ETHUSDT.P, BTC/USDC.P)
  Models/Ticker.swift           Common 24h ticker model (+ Binance decoding), connection status
  Services/MarketDataProvider.swift  Provider protocol + registry; add an exchange here
  Services/BinanceProvider.swift     Binance symbol list for search
  Services/BinanceStream.swift  WebSocket client with exponential-backoff reconnect
  Services/Updater.swift        Checks GitHub Releases, installs the update, relaunches
  Services/TickerStore.swift    App state, persistence (UserDefaults), price formatting
  Services/SymbolDirectory.swift  Symbol list (24h tickers), ranked search, debounced search-as-you-type
  Views/MenuContentView.swift   Dropdown: per-symbol price and 24h stats, remove/reorder, favorites
  Views/SymbolSearchView.swift  Source picker + search field with live results
  Views/FavoritesView.swift     Favorite chips: click to show, drag to reorder
  Views/UpdateBanner.swift      "Update available" banner at the top of the dropdown
assets/
  glance-icon.svg               App icon source (edit this)
  glance-icon.png               1024×1024 render (bundle.sh turns it into AppIcon.icns)
scripts/bundle.sh               Universal release build → build/Glance.app
scripts/dmg.sh                  build/Glance.app → drag-to-install build/Glance.dmg
.github/workflows/              CI build on every push/PR; release on `v*` tags
```

## Roadmap

Phases 1 and 4 are done; 2 and 5 are mostly done.

1. **MVP (done):** a symbol in the menu bar, Binance spot and perp over WebSocket, auto-reconnect, favorites, persistence.
2. **Symbol search (mostly done):** search-as-you-type over all trading spot and perp symbols (from the 24h ticker endpoints, cached 5 min). Still to do: use `tickSize` for exact decimal places.
3. **Menu bar polish:** green/red colored text (render an `NSAttributedString` through `NSStatusItem`, because `MenuBarExtra` labels draw as monochrome templates), an option to flash on price change, and display modes (price, price and %, compact).
4. **Multi-ticker (done):** up to 5 symbols side by side in the menu bar, one WebSocket per symbol.
5. **More exchanges:** the `MarketDataProvider` protocol, source picker, and `EXCHANGE:SYMBOL` parsing are in place. Still to do: Bybit, OKX, Hyperliquid, and Coinbase providers.
6. **Sparkline and alerts:** a mini chart in the dropdown from `@kline_1m`, and price-cross alerts through `UserNotifications`.
7. **Ship it:** Settings window, launch at login (`SMAppService.mainApp`), Developer ID signing and notarization, Sparkle auto-updates. Done so far: app icon, universal build, automated GitHub Releases, and a built-in updater (instead of Sparkle).

## Disclaimer

Glance is an independent project. It isn't affiliated with, endorsed by, or sponsored by Binance or any other exchange. It uses their public market data APIs. Prices may be delayed or wrong, so don't use Glance as your only source for trading decisions. Nothing here is financial advice.

## License

[MIT](LICENSE) © 2026 peetck
