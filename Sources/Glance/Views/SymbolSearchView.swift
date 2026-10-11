import SwiftUI

/// Symbol field with search-as-you-type results. Takes `SymbolSearch` as an `@ObservedObject`
/// because changes in a nested ObservableObject don't refresh views observing `TickerStore`.
struct SymbolSearchView: View {
    @EnvironmentObject private var store: TickerStore
    @ObservedObject var search: SymbolSearch

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                sourcePicker
                TextField("Search symbol, e.g. BTC or ETHUSDC.P", text: $search.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
                    .border(search.inputError ? Color.red : .clear)
            }
            .disabled(store.isFull)
            if store.isFull {
                Text("Showing the maximum of \(TickerStore.maxInstruments) symbols. Remove one to add another.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                results
            }
        }
    }

    /// Exchanges without a provider yet are listed but disabled, so new sources slot in here.
    private var sourcePicker: some View {
        Menu {
            Section("Data source") {
                ForEach(Exchange.allCases) { ex in
                    Button {
                        search.exchange = ex
                    } label: {
                        if ex == search.exchange {
                            Label(ex.displayName, systemImage: "checkmark")
                        } else {
                            Text(ex.isAvailable ? ex.displayName : "\(ex.displayName) (coming soon)")
                        }
                    }
                    .disabled(!ex.isAvailable)
                }
            }
        } label: {
            Text(search.exchange.displayName)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Data source to search")
    }

    @ViewBuilder
    private var results: some View {
        switch search.state {
        case .unsupported:
            Text("\(search.exchange.displayName) isn't supported yet.")
                .font(.caption2).foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading symbols…").font(.caption).foregroundStyle(.secondary)
            }
        case .failed:
            Text("Couldn't load the symbol list. Press Enter to add the symbol as typed.")
                .font(.caption2).foregroundStyle(.secondary)
        case .idle:
            if search.results.isEmpty {
                if !search.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("No matches").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(search.results) { resultRow($0) }
                }
            }
        }
    }

    private func resultRow(_ entry: SymbolEntry) -> some View {
        let shown = store.contains(entry.instrument)
        return Button {
            store.add(entry.instrument)
            search.clear()
        } label: {
            HStack(spacing: 6) {
                Text(entry.instrument.tvSymbol)
                Text(entry.instrument.market == .perp ? "PERP" : "SPOT")
                    .font(.caption2.bold())
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                Spacer()
                Text(PriceFormatter.price(entry.lastPrice))
                    .font(.caption.monospacedDigit())
                Text(PriceFormatter.percent(entry.changePercent))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(entry.changePercent >= 0 ? .green : .red)
                    .frame(width: 56, alignment: .trailing)
                Image(systemName: shown ? "checkmark" : "plus")
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(shown)
    }

    private func submit() {
        guard let inst = search.bestMatch() else {
            search.inputError = true
            return
        }
        store.add(inst)
        search.clear()
    }
}
