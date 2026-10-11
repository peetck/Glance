# Agent notes for Glance

macOS menu bar app (SwiftUI `MenuBarExtra`) that streams Binance prices. README.md has the layout and roadmap; this file holds the rules that aren't obvious from the code.

## Verify every change
- Run `swift build` after each edit. It must finish with no errors. You can ignore the two `ld: warning: search path ... not found` lines.
- Run `./scripts/bundle.sh` → `build/Glance.app` only when a real .app is needed (e.g. testing `Info.plist`/`LSUIElement` behavior). It builds arm64 and x86_64 separately and `lipo`s them; don't switch to a single multi-arch `swift build`, which needs full Xcode.

## Releases
- Bundle ID is `com.peetck.Glance`. Don't change it: macOS keys saved settings by it.
- Pushing a `v*` tag runs `.github/workflows/release.yml`, which builds with `VERSION=<tag without v>` and publishes a GitHub Release. The app is ad-hoc signed, not notarized.
- User-facing changes get a line under **Unreleased** in CHANGELOG.md.

## Toolchain: Command Line Tools only, no full Xcode
- **Do not use Swift macros**: `@State`, `@Observable`, `@Bindable`, `#Preview`, etc. The macro plugins ship only with full Xcode, so the build fails.
- For state use an `ObservableObject` + `@StateObject`/`@ObservedObject` with `@Published` properties (app state lives on `TickerStore`).
- A nested ObservableObject (e.g. `TickerStore.search`) doesn't refresh views observing the parent. Pass it into a subview as `@ObservedObject` (see `SymbolSearchView`).
- Target is macOS 14 (`Package.swift`). Don't use APIs newer than that without an availability check.

## Data sources
- Each exchange is an `Exchange` case. It works only if `Providers.provider(for:)` returns a `MarketDataProvider`; otherwise the UI lists it as "coming soon" and its instruments show "Unsupported".
- To add an exchange, implement `MarketDataProvider` (a `TickerStream` for live prices + `fetchSymbols()` for search), register it in `Providers`, and map its payloads to `MiniTicker`/`SymbolEntry`. Keep exchange-specific code in that provider's files.
- `Instrument.id` includes the exchange (`BINANCE:BTCUSDC.P`), so the same symbol on two exchanges counts as two instruments.

## Binance gotchas
- USDⓈ-M perp streams must use `wss://fstream.binance.com/market/ws/...`. The legacy `/ws/` path connects but never sends data.
- Spot (`stream.binance.com:9443`) and perp (`fstream.binance.com`) are different hosts, which is why there is one `BinanceStream` (one socket) per instrument instead of a combined stream.
- miniTicker numbers arrive as strings. `MiniTicker` decodes them into `Double`.
- Symbol search uses the 24h ticker endpoints, not `exchangeInfo` (~1.3 MB vs ~7 MB). The spot list includes delisted symbols, so `SymbolDirectory` filters out symbols with no trades in the last 24h. Ranking is by trade count, because quote volume depends on the quote currency.
- Symbols use TradingView notation: `BTCUSDC.P` = perp, `BTCUSDT` = spot. Parsing lives in `Instrument(tvSymbol:)`.

## App rules
- The user can show 0–5 symbols at once (`TickerStore.maxInstruments`). With 0, the menu bar shows an SF Symbol icon so the dropdown stays reachable. Never let the label become empty.
- Persistence is JSON in `UserDefaults`:
  - `instruments` holds the shown symbols, in order.
  - `favorites` holds the favorite symbols.
  - `instrument` is a legacy single-symbol key, read only for migration.
  - Saved instruments without an `exchange` field decode as Binance.
  - When you change a stored type, keep decoding the old shape or migrate it. Don't silently reset user data.
- Favorites are reordered by drag and drop (`FavoritesView`, payload = `Instrument.id`). Chips use `onTapGesture`, not `Button`, so the drag isn't swallowed.
- Stream callbacks check `streams[instrument] === stream` so late updates from a stopped socket are dropped. Keep that guard when touching connection code.

## Code style
- State and logic go in `TickerStore` (`@MainActor`). Views only render and call store methods.
- Price/number formatting goes through `PriceFormatter`.
- No third-party dependencies unless asked. Keep it buildable with plain `swift build`.
- Match existing style: small files by role (`App/`, `Models/`, `Services/`, `Views/`), sparse comments that explain *why*.
- When a roadmap item in README.md is finished, or a feature changes what README describes, update README in the same change.
