import PhotosUI
import SwiftUI

struct LogoSection: View {
  @Bindable var draft: EditorDraft
  @State private var photo: PhotosPickerItem?
  @State private var pickingPhoto = false
  @State private var importingFile = false
  @State private var loadError: String?

  var body: some View {
    Section {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          Button {
            draft.logo = .none
          } label: {
            LogoTile(isSelected: draft.logo == .none) {
              Image(systemName: "circle.slash").foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("No logo")

          Menu {
            Button("Photos", systemImage: "photo.on.rectangle") { pickingPhoto = true }
            Button("Files", systemImage: "folder") { importingFile = true }
          } label: {
            LogoTile(isSelected: draft.logo.kind == .custom) {
              if case .custom(let data) = draft.logo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().padding(6)
              } else {
                Image(systemName: "photo.badge.plus").foregroundStyle(.secondary)
              }
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Custom logo")

          ForEach(Presets.all.filter { $0.logoName != nil }) { preset in
            Button {
              draft.logo = preset.logo
            } label: {
              PresetLogoThumb(preset: preset)
                .overlay {
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(draft.logo == preset.logo ? Color.accentColor : .clear, lineWidth: 2.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(preset.name) logo")
            .accessibilityAddTraits(draft.logo == preset.logo ? .isSelected : [])
          }
        }
        .padding(.vertical, 4)
      }
      .scrollEdgeFades()
      if let loadError { FieldMessage(text: loadError, isError: true) }
    } header: {
      Text("Logo")
    } footer: {
      if draft.logo.kind == .custom {
        Text("White artwork on a transparent background looks best on the header.")
      }
    }
    .photosPicker(isPresented: $pickingPhoto, selection: $photo, matching: .images)
    .onChange(of: photo) { _, item in
      guard let item else { return }
      Task {
        let data = try? await item.loadTransferable(type: Data.self)
        setCustomLogo(data)
      }
    }
    .fileImporter(isPresented: $importingFile, allowedContentTypes: [.image]) { result in
      guard case .success(let url) = result else { return }
      let accessing = url.startAccessingSecurityScopedResource()
      defer { if accessing { url.stopAccessingSecurityScopedResource() } }
      setCustomLogo(try? Data(contentsOf: url))
    }
  }

  private func setCustomLogo(_ data: Data?) {
    guard let data, let png = LogoImport.downscaledPNG(data) else {
      loadError = "Couldn't read that image"
      return
    }
    loadError = nil
    draft.logo = .custom(png)
  }
}

/// A 52×30 tile matching `PresetLogoThumb`, for the non-preset logo choices.
private struct LogoTile<Content: View>: View {
  let isSelected: Bool
  @ViewBuilder let content: Content

  var body: some View {
    ZStack {
      Color(.tertiarySystemFill)
      content
    }
    .frame(width: 52, height: 30)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

enum LogoImport {
  /// Downscales to fit 960×240 px and re-encodes as PNG (keeps transparency). Headers draw
  /// logos ~30 pt tall; WidgetKit drops any widget holding an image over ~1 MP.
  static func downscaledPNG(_ data: Data, maxSize: CGSize = CGSize(width: 960, height: 240)) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    let factor = min(1, maxSize.width / max(pixelWidth, 1), maxSize.height / max(pixelHeight, 1))
    let target = CGSize(width: (pixelWidth * factor).rounded(), height: (pixelHeight * factor).rounded())
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(size: target, format: format).pngData { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
