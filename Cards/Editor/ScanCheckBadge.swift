import SwiftUI

/// Renders the preview at medium size and reads it back with the barcode decoder
/// (debounced), so a code squeezed too small shows up before saving.
struct ScanCheckBadge: View {
  let snapshot: CardSnapshot
  let size: CGSize

  enum Status: Equatable { case checking, scannable, hard, none }
  @State private var status: Status = .checking

  var body: some View {
    HStack(spacing: 6) {
      switch status {
      case .checking:
        ProgressView().controlSize(.mini)
        Text("Checking…")
      case .scannable:
        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        Text("Scannable")
      case .hard:
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        Text("Hard to scan at this size")
      case .none:
        EmptyView()
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(height: 16)
    .task(id: checkKey) {
      status = .checking
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      status = check()
    }
  }

  /// Żappka payloads change every 30 s; check once per window rather than per tick.
  private var checkKey: String {
    let window = snapshot.isZappka ? Zappka.window(containing: .now).start.timeIntervalSince1970 : 0
    return "\(snapshot.hashValue)|\(window)"
  }

  @MainActor
  private func check() -> Status {
    let date = Date.now
    guard case .code(let text, _, let isSample) = CardCode.resolve(snapshot, at: date), !isSample else { return .none }
    let view = CardView(card: snapshot, family: .medium, date: date)
      .frame(width: size.width, height: size.height)
      .environment(\.displayScale, 3)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    guard let image = renderer.cgImage else { return .hard }
    let decoded = BarcodeDecoder.decode(image)
    return decoded.contains { BarcodeDecoder.matches($0, text: text, symbology: snapshot.symbology) } ? .scannable : .hard
  }
}
