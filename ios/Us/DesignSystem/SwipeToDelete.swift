import SwiftUI

/// A row you can swipe left to reveal a **Delete** action (and, optionally, an
/// **Edit** action) — usable inside a `ScrollView`, where `List`'s native
/// `.swipeActions` aren't available.
///
/// The action buttons are only rendered while the row is swiped, so nothing
/// bleeds through the translucent content when the row is closed. The content
/// slides on its own `.regularMaterial` backing so it reads consistently with
/// the surrounding cards.
struct SwipeToDelete<Content: View>: View {
    var onDelete: () -> Void
    var onEdit: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var open = false

    private let buttonWidth: CGFloat = 68
    private let gap: CGFloat = 8
    private var revealWidth: CGFloat {
        let count = onEdit == nil ? 1 : 2
        return CGFloat(count) * buttonWidth + CGFloat(count) * gap
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < -0.5 { actions }

            content()
                // Backing only while swiping, so the row looks untouched at rest
                // yet cleanly covers the actions as it slides.
                .background(
                    offset < -0.5 ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .offset(x: offset)
                // Simultaneous (not high-priority) so vertical scrolling of the
                // feed is never blocked; the gesture only moves the row on a
                // horizontal-dominant drag, and the vertical ScrollView ignores
                // horizontal motion — so the two coexist cleanly.
                .simultaneousGesture(dragGesture)
                // Tapping an open row closes it instead of hitting the content.
                .overlay {
                    if open {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { close() }
                    }
                }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: offset)
    }

    private var actions: some View {
        HStack(spacing: gap) {
            if let onEdit {
                actionButton(title: "Edit", icon: "pencil", tint: Theme.rose) { close(); onEdit() }
            }
            actionButton(title: "Delete", icon: "trash.fill", tint: .red) { close(); onDelete() }
        }
    }

    private func actionButton(title: String, icon: String, tint: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: buttonWidth)
            .frame(maxHeight: .infinity)
            .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                // Only react to a mostly-horizontal drag so vertical scrolling
                // through the feed still works normally.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let base: CGFloat = open ? -revealWidth : 0
                offset = min(0, max(-revealWidth - 28, base + value.translation.width))
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) || open else {
                    offset = open ? -revealWidth : 0
                    return
                }
                let projected = offset + value.predictedEndTranslation.width * 0.25
                if projected < -revealWidth / 2 {
                    open = true; offset = -revealWidth
                } else {
                    close()
                }
            }
    }

    private func close() { open = false; offset = 0 }
}
