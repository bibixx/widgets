import SwiftUI

/// Checkout mode: white screen, the card as large as possible, brightness at 100%.
/// Swipe sideways between cards, swipe down (or Done) to dismiss.
struct CardFullscreenView: View {
  let cards: [Card]
  @Binding var selection: UUID?
  @Environment(\.dismiss) private var dismiss
  @State private var brightness = BrightnessBooster()

  var body: some View {
    TabView(selection: $selection) {
      ForEach(cards) { card in
        CheckoutPage(card: card.snapshot())
          .tag(Optional(card.id))
      }
    }
    .tabViewStyle(.page(indexDisplayMode: cards.count > 1 ? .automatic : .never))
    .indexViewStyle(.page(backgroundDisplayMode: .always))
    .background(Color.white.ignoresSafeArea())
    .overlay(alignment: .topTrailing) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.title)
          .symbolRenderingMode(.palette)
          .foregroundStyle(.white, .black.opacity(0.35))
      }
      .padding()
      .accessibilityLabel("Done")
    }
    .gesture(DragGesture(minimumDistance: 40).onEnded { value in
      if value.translation.height > 120, abs(value.translation.width) < 80 { dismiss() }
    })
    .onAppear { brightness.boost() }
    .onDisappear { brightness.restore() }
    .preferredColorScheme(.light)
    .statusBarHidden()
  }
}

private struct CheckoutPage: View {
  let card: CardSnapshot
  @State private var lastWindowStart: Date?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: 24) {
        GeometryReader { proxy in
          CardView(card: card, family: .fullscreen, date: context.date, showsCountdown: false)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        if card.isZappka {
          let window = Zappka.window(containing: context.date)
          VStack(spacing: 4) {
            Text(Zappka.code(for: card.zappkaCredentials ?? .init(userId: "", secretHex: ""), at: context.date) ?? "")
              .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
            Text("New code in \(Int(window.end.timeIntervalSince(context.date).rounded(.up))) s")
              .font(.headline)
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }
          .foregroundStyle(.black)
          .onChange(of: window.start) { _, _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
          }
          .padding(.bottom, 40)
        }
      }
    }
    .ignoresSafeArea(edges: .top)
  }
}

/// Maxes the screen brightness and keeps the screen awake; restores both afterwards.
@MainActor
final class BrightnessBooster {
  private var saved: CGFloat?

  private var screen: UIScreen? {
    UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
  }

  func boost() {
    guard let screen, saved == nil else { return }
    saved = screen.brightness
    screen.brightness = 1
    UIApplication.shared.isIdleTimerDisabled = true
  }

  func restore() {
    if let saved, let screen { screen.brightness = saved }
    saved = nil
    UIApplication.shared.isIdleTimerDisabled = false
  }
}
