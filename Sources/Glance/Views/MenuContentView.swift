import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var store: TickerStore
    // Plain ObservableObject instead of @State: @State is a macro in the macOS 27 SDK and its
    // plugin ships only with full Xcode, so this keeps the project buildable with Command Line Tools.
    @StateObject private var form = SymbolForm()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            symbolInput
            favoritesList
            Divider()
            HStack {
                Text("Data: Binance").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(store.instrument.tvSymbol).font(.headline)
                Text(store.instrument.market == .perp ? "PERP" : "SPOT")
                    .font(.caption2.bold())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                Spacer()
                statusDot
            }
            if let t = store.ticker {
                HStack(alignment: .firstTextBaseline) {
                    Text(PriceFormatter.price(t.close))
                        .font(.system(size: 26, weight: .semibold).monospacedDigit())
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
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var symbolInput: some View {
        HStack {
            TextField("Symbol, e.g. BTCUSDC.P", text: $form.input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
                .border(form.inputError ? Color.red : .clear)
            Button("Go", action: submit)
        }
    }

    private var favoritesList: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Favorites").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.toggleFavorite(store.instrument)
                } label: {
                    Image(systemName: store.favorites.contains(store.instrument) ? "star.fill" : "star")
                }
                .buttonStyle(.borderless)
                .help("Toggle current symbol in favorites")
            }
            ForEach(store.favorites) { inst in
                Button {
                    store.select(inst)
                } label: {
                    HStack {
                        Text(inst.tvSymbol)
                        Spacer()
                        if inst == store.instrument { Image(systemName: "checkmark") }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
            }
        }
    }

    private var statusDot: some View {
        let (color, label): (Color, String) = switch store.status {
        case .live: (.green, "Live")
        case .connecting: (.yellow, "Connecting")
        case .reconnecting(let s): (.orange, "Retry in \(s)s")
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

    private func submit() {
        guard let inst = Instrument(tvSymbol: form.input) else {
            form.inputError = true
            return
        }
        form.inputError = false
        form.input = ""
        store.select(inst)
    }
}

final class SymbolForm: ObservableObject {
    @Published var input = ""
    @Published var inputError = false
}
