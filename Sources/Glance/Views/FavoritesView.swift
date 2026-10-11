import SwiftUI

/// Favorites as a grid of chips: click to show or hide in the menu bar, drag to reorder.
struct FavoritesView: View {
    @EnvironmentObject private var store: TickerStore
    // ObservableObject instead of @State (a macro; see AGENTS.md).
    @StateObject private var drag = DragState()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Favorites").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if !store.favorites.isEmpty {
                    Text("Click to show · drag to reorder").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            if store.favorites.isEmpty {
                HStack(spacing: 4) {
                    Text("Tap")
                    Image(systemName: "star")
                    Text("on a shown symbol to save it here.")
                }
                .font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(store.favorites) { chip($0) }
                }
            }
        }
    }

    private func chip(_ inst: Instrument) -> some View {
        let shown = store.contains(inst)
        let unavailable = !shown && store.isFull
        let base = TickerStore.baseAsset(inst.symbol)
        let quote = inst.symbol.dropFirst(base.count)
        let isDropTarget = drag.target == inst
        return VStack(spacing: 1) {
            Text(base)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text([String(quote), inst.market == .perp ? "PERP" : "SPOT"].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(shown ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .foregroundStyle(shown ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(shown ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary.opacity(0.6)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDropTarget ? Color.accentColor : shown ? .clear : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1, dash: isDropTarget ? [4, 3] : [])
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .opacity(unavailable ? 0.4 : 1)
        // A tap gesture rather than a Button, so the drag below isn't swallowed by the button.
        .onTapGesture { if !unavailable { store.toggle(inst) } }
        .draggable(inst.id)
        .dropDestination(for: String.self) { ids, _ in
            drag.target = nil
            guard let id = ids.first, let dragged = store.favorites.first(where: { $0.id == id }) else { return false }
            withAnimation(.snappy(duration: 0.2)) { store.moveFavorite(dragged, to: inst) }
            return true
        } isTargeted: { targeted in
            if targeted { drag.target = inst } else if drag.target == inst { drag.target = nil }
        }
        .help(help(inst, shown: shown, unavailable: unavailable))
        .contextMenu {
            Button("Move Left") { store.moveFavorite(inst, by: -1) }
                .disabled(store.favorites.first == inst)
            Button("Move Right") { store.moveFavorite(inst, by: 1) }
                .disabled(store.favorites.last == inst)
            Divider()
            Button("Remove from Favorites") { store.toggleFavorite(inst) }
        }
    }

    private func help(_ inst: Instrument, shown: Bool, unavailable: Bool) -> String {
        let name = "\(inst.tvSymbol) on \(inst.exchange.displayName)"
        if shown { return "Hide \(name) from the menu bar" }
        if unavailable { return "Remove a symbol to show \(name)" }
        return "Show \(name) in the menu bar"
    }
}

private final class DragState: ObservableObject {
    @Published var target: Instrument?
}
