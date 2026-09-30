import SwiftUI

struct ScrollEdgeFades: ViewModifier {
  var width: CGFloat = 24

  @State private var fadesLeading = false
  @State private var fadesTrailing = false

  private struct HiddenEdges: Equatable {
    var leading: Bool
    var trailing: Bool
  }

  func body(content: Content) -> some View {
    content
      .onScrollGeometryChange(for: HiddenEdges.self) { geometry in
        let visible = geometry.visibleRect
        return HiddenEdges(
          leading: visible.minX > 1,
          trailing: visible.maxX < geometry.contentSize.width - 1
        )
      } action: { _, edges in
        withAnimation(.easeOut(duration: 0.2)) {
          fadesLeading = edges.leading
          fadesTrailing = edges.trailing
        }
      }
      .mask {
        HStack(spacing: 0) {
          edge(fading: fadesLeading, from: .leading)
          Rectangle()
          edge(fading: fadesTrailing, from: .trailing)
        }
      }
  }

  private func edge(fading: Bool, from start: UnitPoint) -> some View {
    LinearGradient(
      colors: [.black.opacity(fading ? 0 : 1), .black],
      startPoint: start,
      endPoint: start == .leading ? .trailing : .leading
    )
    .frame(width: width)
  }
}

extension View {
  /// Fades the edges of a horizontal scroll view where content is scrolled out of sight.
  func scrollEdgeFades() -> some View {
    modifier(ScrollEdgeFades())
  }
}
