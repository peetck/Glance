# Contributing to Glance

Thanks for helping! Bug reports, ideas, and pull requests are all welcome.

## Getting started

```sh
git clone https://github.com/peetck/Glance.git
cd Glance
swift run
```

You only need the Xcode Command Line Tools (`xcode-select --install`) and macOS 14 or later.

## Before you open a pull request

- `swift build` passes.
- You tried the change in the running app (`swift run`, or `./scripts/bundle.sh && open build/Glance.app`).
- README.md and CHANGELOG.md (under **Unreleased**) are updated if the change is user-facing.
- One feature or fix per pull request, so it's easy to review.

## Things to know

[AGENTS.md](AGENTS.md) has the project's rules. The main ones:

- **No Swift macros** (`@State`, `@Observable`, `#Preview`). The project builds with Command Line Tools only, and those don't ship the macro plugins. Use `ObservableObject` instead.
- **App state and logic live in `TickerStore`;** views only render.
- **No third-party dependencies** without discussing it in an issue first.

## Adding an exchange

The most useful contribution! Implement `MarketDataProvider` (a live `TickerStream` and `fetchSymbols()` for search), then register it in `Providers.provider(for:)`. The source picker enables it automatically. See `BinanceProvider.swift` and `BinanceStream.swift` for a working example. Please use only public, no-API-key endpoints.

## Releasing (maintainers)

1. Move the **Unreleased** notes in CHANGELOG.md under a new version heading.
2. `git tag v0.2.0 && git push origin v0.2.0`
3. GitHub Actions builds the app and publishes the release.
