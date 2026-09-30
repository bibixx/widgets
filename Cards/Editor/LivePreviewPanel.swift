import SwiftUI

/// Pinned above the editor form: the real CardView, redrawn on every draft change and
/// ticking every second, in any size and rendering mode.
struct LivePreviewPanel: View {
  enum SizeChoice: String, CaseIterable, Identifiable {
    case small, medium, large, fullscreen, all
    var id: String { rawValue }
    var label: String {
      switch self {
      case .small: "S"
      case .medium: "M"
      case .large: "L"
      case .fullscreen: "Full"
      case .all: "All"
      }
    }
  }

  enum Wallpaper: String, CaseIterable, Identifiable {
    case light, dark, colourful
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
  }

  let draft: EditorDraft
  @State private var sizeChoice: SizeChoice = .medium
  @State private var renderingMode: CardRenderingMode = .fullColor
  @State private var wallpaper: Wallpaper = .light
  @State private var expanded = true

  private let sizes = WidgetSizes.current

  var body: some View {
    VStack(spacing: 10) {
      if expanded {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          preview(snapshot: draft.snapshot(), date: context.date)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(wallpaperBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

        ScanCheckBadge(snapshot: draft.snapshot(), size: sizes.medium)
      }
      controls
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(.bar)
  }

  @ViewBuilder
  private func preview(snapshot: CardSnapshot, date: Date) -> some View {
    switch sizeChoice {
    case .all:
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 12) {
          widget(snapshot, .small, date)
          widget(snapshot, .medium, date)
          widget(snapshot, .large, date)
        }
        .padding(.horizontal, 12)
      }
      .frame(height: min(sizes.large.height, 260))
      .scaleEffectToFit(height: sizes.large.height, into: 260)
    case .small: widget(snapshot, .small, date)
    case .medium: widget(snapshot, .medium, date)
    case .large: widget(snapshot, .large, date).scaleEffectToFit(height: sizes.large.height, into: 280)
    case .fullscreen:
      widget(snapshot, .fullscreen, date).scaleEffectToFit(height: sizes.size(for: .fullscreen).height, into: 300)
    }
  }

  private func widget(_ snapshot: CardSnapshot, _ family: CardFamily, _ date: Date) -> some View {
    let size = sizes.size(for: family)
    return CardView(card: snapshot, family: family, date: date, renderingMode: renderingMode)
      .frame(width: size.width, height: size.height)
      .background(renderingMode == .fullColor ? Color.clear : tintedGlass)
      .clipShape(RoundedRectangle(cornerRadius: family == .fullscreen ? 0 : 22, style: .continuous))
      .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
  }

  private var tintedGlass: Color {
    switch renderingMode {
    case .accented: Color(red: 0.12, green: 0.16, blue: 0.28).opacity(0.85)
    case .vibrant: Color.white.opacity(0.18)
    case .fullColor: .clear
    }
  }

  private var wallpaperBackground: AnyShapeStyle {
    switch wallpaper {
    case .light: AnyShapeStyle(Color(white: 0.92))
    case .dark: AnyShapeStyle(Color(white: 0.12))
    case .colourful: AnyShapeStyle(LinearGradient(colors: [.purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
  }

  private var controls: some View {
    HStack(spacing: 8) {
      Picker("Size", selection: $sizeChoice) {
        ForEach(SizeChoice.allCases) { Text($0.label).tag($0) }
      }
      .pickerStyle(.segmented)

      Menu {
        Picker("Rendering", selection: $renderingMode) {
          ForEach(CardRenderingMode.allCases) { Text($0.displayName).tag($0) }
        }
        Picker("Wallpaper", selection: $wallpaper) {
          ForEach(Wallpaper.allCases) { Text($0.label).tag($0) }
        }
      } label: {
        Image(systemName: renderingMode == .fullColor ? "paintpalette" : "paintpalette.fill")
      }
      .accessibilityLabel("Preview style")

      Button {
        withAnimation(.snappy) { expanded.toggle() }
      } label: {
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
      }
      .accessibilityLabel(expanded ? "Collapse preview" : "Expand preview")
    }
  }
}

private extension View {
  /// Scales content of the given natural height down to fit `target` (never up).
  func scaleEffectToFit(height natural: CGFloat, into target: CGFloat) -> some View {
    let scale = min(1, target / max(natural, 1))
    return scaleEffect(scale).frame(height: natural * scale)
  }
}
