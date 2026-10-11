import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var store: TickerStore
    @EnvironmentObject private var updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UpdateBanner(updater: updater)
            tickerList
            Divider()
            SymbolSearchView(search: store.search)
            FavoritesView()
            Divider()
            HStack {
                Text("Data: " + (store.activeExchanges.isEmpty ? [Exchange.default] : store.activeExchanges)
                    .map(\.displayName).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                settingsMenu
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var settingsMenu: some View {
        Menu {
            Button("Check for Updates…") { Task { await updater.checkForUpdates() } }
            Toggle("Check for Updates Automatically", isOn: $updater.checksAutomatically)
            Divider()
            Text("Glance \(updater.currentVersion ?? "dev build")")
        } label: {
            Image(systemName: "gearshape")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Settings")
    }

    private var tickerList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.instruments.isEmpty {
                Text("No symbols shown. Add one below or pick a favorite.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(store.instruments.enumerated()), id: \.element) { index, inst in
                if index > 0 { Divider().opacity(0.5) }
                tickerRow(inst, index: index)
            }
        }
    }

    private func tickerRow(_ inst: Instrument, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(inst.tvSymbol).font(.headline)
                Text("\(inst.exchange.displayName) · \(inst.market == .perp ? "PERP" : "SPOT")")
                    .font(.caption2.bold())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                favoriteButton(inst)
                Spacer()
                statusDot(store.statuses[inst] ?? .connecting)
                rowControls(inst, index: index)
            }
            if let t = store.tickers[inst] {
                HStack(alignment: .firstTextBaseline) {
                    Text(PriceFormatter.price(t.close))
                        .font(.system(size: store.instruments.count > 1 ? 20 : 26, weight: .semibold).monospacedDigit())
                    Text(PriceFormatter.percent(t.changePercent))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(t.changePercent >= 0 ? .green : .red)
                }
                Grid(alignment: .leading, horizontalSpacing: 12) {
                    GridRow {
                        stat("24h High", PriceFormatter.price(t.high))
                        stat("24h Low", PriceFormatter.price(t.low))
                        stat("Vol", PriceFormatter.compact(t.quoteVolume))
                    }
                }
            } else if store.statuses[inst] == .unsupported {
                Text("\(inst.exchange.displayName) isn't supported yet.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func rowControls(_ inst: Instrument, index: Int) -> some View {
        HStack(spacing: 2) {
            if store.instruments.count > 1 {
                Button { store.move(inst, by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(index == 0)
                    .help("Move left in menu bar")
                Button { store.move(inst, by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(index == store.instruments.count - 1)
                    .help("Move right in menu bar")
            }
            Button { store.remove(inst) } label: { Image(systemName: "xmark.circle.fill") }
                .help("Remove")
        }
        .buttonStyle(.borderless)
        .imageScale(.small)
        .foregroundStyle(.secondary)
    }

    private func favoriteButton(_ inst: Instrument) -> some View {
        let isFavorite = store.favorites.contains(inst)
        return Button { store.toggleFavorite(inst) } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundStyle(isFavorite ? Color.yellow : .secondary)
        }
        .buttonStyle(.borderless)
        .help(isFavorite ? "Remove from favorites" : "Add to favorites")
    }

    private func statusDot(_ status: ConnectionStatus) -> some View {
        let (color, label): (Color, String) = switch status {
        case .live: (.green, "Live")
        case .connecting: (.yellow, "Connecting")
        case .reconnecting(let s): (.orange, "Retry in \(s)s")
        case .unsupported: (.gray, "Unsupported")
        }
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit())
        }
    }
}
