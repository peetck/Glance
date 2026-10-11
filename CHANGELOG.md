# Changelog

All notable changes to Glance. Versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

## [0.4.0] - 2026-10-12

### Changed
- Prices show 2 decimals (62,431.50). Prices below 1 keep 4 significant digits so small coins stay readable.
- Removed the "Data: Binance" label from the dropdown footer.

## [0.3.0] - 2026-10-12

### Added
- Auto-update: checks GitHub Releases daily (can be turned off in ⚙︎), downloads the new version, and relaunches. Also available as ⚙︎ → Check for Updates….

### Changed
- Releases are now a drag-to-install `.dmg` instead of a `.zip`.

## [0.2.0] - 2026-10-12

### Added
- Show up to 5 tickers at once in the menu bar, or none.
- Search as you type across all trading Binance spot and perp symbols.
- Favorites as chips: click to show or hide, drag to reorder.
- Data source picker and `MarketDataProvider` protocol, ready for more exchanges.
- App icon, universal (Apple silicon + Intel) build, and automated GitHub Releases.

### Changed
- Bundle ID is now `com.peetck.Glance`. Settings saved by earlier builds (bundle ID `dev.private.Glance`) don't carry over.

## [0.1.0]

### Added
- First version: one Binance symbol in the menu bar, auto-reconnect, favorites.
