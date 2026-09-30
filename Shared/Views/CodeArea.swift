import SwiftUI
import WidgetKit

/// The code (or a problem tile) placed inside the card's code area.
struct CodeArea: View {
  let card: CardSnapshot
  let code: CardCode
  let metrics: CardLayout.Metrics
  var renderingMode: CardRenderingMode = .fullColor
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    let area = metrics.codeArea
    Group {
      switch code {
      case .code(let text, let caption, let isSample):
        codeImage(text: text, caption: caption, isSample: isSample, area: area)
      case .problem(let symbol, let message):
        ProblemTile(symbol: symbol, message: message, compact: area.height < 60)
          .frame(width: area.width, height: area.height)
          .position(x: area.midX, y: area.midY)
      }
    }
  }

  @ViewBuilder
  private func codeImage(text: String, caption: String?, isSample: Bool, area: CGRect) -> some View {
    let symbology = card.symbology
    if let matrixSize = try? CodeRaster.matrixSize(for: text, symbology: symbology) {
      let rect = CardLayout.codeRect(in: area, symbology: symbology, matrixSize: matrixSize)
      // Without the white card body (tinted/clear modes) the code brings its own white plate.
      let plate = renderingMode == .fullColor ? 0 : metrics.codeInset * 0.75
      // A linear code needs ~10 modules of white either side; the plate alone is too thin
      // once the bars fill the box, so the bars shrink inside it (tinted/clear only).
      let quietX = plate > 0 && symbology.kind == .linear
        ? max(plate, (rect.width + 2 * plate) * 10 / (matrixSize.width + 20))
        : plate
      let codeWidth = rect.width + 2 * (plate - quietX)
      let pixelWidth = Int((codeWidth * displayScale).rounded())
      let pixelHeight = Int((rect.height * displayScale).rounded())
      let (notch, captionSpec) = captionParts(caption, pixelWidth: pixelWidth)
      if let image = try? CodeRaster.image(
        for: text, symbology: symbology, pixelWidth: pixelWidth, pixelHeight: pixelHeight, notch: notch,
        caption: captionSpec, padding: Int((plate * displayScale).rounded()),
        paddingX: Int((quietX * displayScale).rounded()))
      {
        Image(decorative: image, scale: displayScale)
          .resizable()
          .interpolation(.none)
          .antialiased(false)
          // Scanners need true black on white: keep the system from tinting/desaturating it.
          .widgetAccentedRenderingMode(.fullColor)
          .frame(width: rect.width + 2 * plate, height: rect.height + 2 * plate)
          .clipShape(
            plate > 0
              ? RoundedRectangle(cornerRadius: plate * 0.6, style: .circular)
              : RoundedRectangle(cornerSize: CardLayout.codeCornerSize(for: symbology), style: .circular))
          .opacity(isSample ? 0.3 : 1)
          .overlay(alignment: .topTrailing) { if isSample { SampleBadge().offset(y: -8) } }
          .position(x: rect.midX, y: rect.midY)
      }
    } else {
      ProblemTile(symbol: "exclamationmark.triangle", message: "Can't draw this code", compact: area.height < 60)
        .frame(width: area.width, height: area.height)
        .position(x: area.midX, y: area.midY)
    }
  }

  private func captionParts(_ caption: String?, pixelWidth: Int) -> (CodeRaster.Notch?, CodeRaster.Caption?) {
    guard let caption, card.symbology.kind == .linear else { return (nil, nil) }
    let s = displayScale
    let center = CGFloat(pixelWidth) / 2
    let halfBox = metrics.notchWidth(characters: caption.count) / 2 * s
    let notch = CodeRaster.Notch(
      minX: Int((center - halfBox).rounded()), maxX: Int((center + halfBox).rounded()),
      height: Int((metrics.notchHeight * s).rounded()),
      topRadius: Int((metrics.notchTopRadius * s).rounded()))
    let spec = CodeRaster.Caption(
      text: caption, fontSize: metrics.captionFontSize * s, tracking: metrics.captionTracking * s,
      baseline: metrics.captionBaseline * s, centerX: center)
    return (notch, spec)
  }
}

struct ProblemTile: View {
  let symbol: String
  let message: String
  var compact = false

  var body: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
      .fill(Color.gray.opacity(0.12))
      .overlay {
        VStack(spacing: 4) {
          Image(systemName: symbol).font(compact ? .footnote : .title3)
          Text(message)
            .font(compact ? .caption2 : .footnote)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.secondary)
        .padding(6)
      }
  }
}

struct SampleBadge: View {
  var body: some View {
    Text("Sample")
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(.orange, in: Capsule())
      .foregroundStyle(.white)
  }
}
