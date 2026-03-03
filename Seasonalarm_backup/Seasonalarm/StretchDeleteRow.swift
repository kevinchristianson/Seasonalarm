import SwiftUI

struct StretchDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var settled:    CGFloat = 0      // 0 = closed, -maxReveal = open
    @State private var liveDrag:   CGFloat = 0      // added on top of settled during active drag
    @State private var isTracking: Bool    = false  // true once we've committed to this gesture
    @State private var deleting:   Bool    = false

    private let maxReveal: CGFloat = 88
    private let threshold: CGFloat = 36

    private var offset: CGFloat {
        let raw = settled + liveDrag
        if raw < -maxReveal {
            return -maxReveal - rubberBand(-(raw + maxReveal), limit: maxReveal * 0.4)
        }
        if raw > 0 {
            return rubberBand(raw, limit: 12)
        }
        return raw
    }

    private var revealWidth: CGFloat { max(0, -offset) }

    var body: some View {
        ZStack(alignment: .trailing) {
            if revealWidth > 0 {
                deleteZone
                    .frame(width: revealWidth)
                    .clipped()
            }

            content()
                .offset(x: deleting ? -UIScreen.main.bounds.width : offset)
                .highPriorityGesture(swipeGesture)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard settled < 0 else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { settled = 0 }
        }
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: settled)
        .animation(.easeIn(duration: 0.18), value: deleting)
    }

    // MARK: - Delete zone

    private var deleteZone: some View {
        Button {
            withAnimation(.easeIn(duration: 0.18)) { deleting = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDelete() }
        } label: {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 1, green: 0.22, blue: 0.22))
                .overlay(
                    VStack(spacing: 3) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("DELETE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .opacity(min(1.0, revealWidth / maxReveal))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gesture
    //
    // Key fix: we use @State (not @GestureState) for liveDrag so it doesn't
    // auto-reset mid-gesture. We commit to "horizontal" on the first movement
    // that qualifies, then track unconditionally for the rest of that drag.

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                if !isTracking {
                    // Only commit if the gesture is primarily horizontal
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    isTracking = true
                }
                liveDrag = value.translation.width
            }
            .onEnded { value in
                defer {
                    liveDrag   = 0
                    isTracking = false
                }
                guard isTracking else { return }

                let dx       = value.translation.width
                let velocity = value.predictedEndTranslation.width - value.translation.width

                let shouldOpen: Bool
                if settled == 0 {
                    shouldOpen = dx < -threshold || velocity < -120
                } else {
                    shouldOpen = !(dx > threshold || velocity > 120)
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    settled  = shouldOpen ? -maxReveal : 0
                    liveDrag = 0
                }
            }
    }

    private func rubberBand(_ x: CGFloat, limit: CGFloat) -> CGFloat {
        limit * (1 - exp(-x / limit))
    }
}
