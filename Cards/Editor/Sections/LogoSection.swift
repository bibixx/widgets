import PhotosUI
import SwiftUI

struct LogoSection: View {
  @Bindable var draft: EditorDraft
  @State private var photo: PhotosPickerItem?
  @State private var importingFile = false
  @State private var loadError: String?

  var body: some View {
    Section {
      Picker("Logo", selection: kindBinding) {
        Text("None").tag(CardLogo.Kind.none)
        Text("Preset").tag(CardLogo.Kind.preset)
        Text("Custom").tag(CardLogo.Kind.custom)
      }
      .pickerStyle(.segmented)

      switch draft.logo.kind {
      case .none:
        EmptyView()
      case .preset:
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
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
            }
          }
          .padding(.vertical, 4)
        }
      case .custom:
        HStack {
          PhotosPicker("Photos", selection: $photo, matching: .images)
          Spacer()
          Button("Files") { importingFile = true }
        }
        .buttonStyle(.borderless)
      }
      if let loadError { FieldMessage(text: loadError, isError: true) }
    } header: {
      Text("Logo")
    } footer: {
      if draft.logo.kind == .custom {
        Text("White artwork on a transparent background looks best on the header.")
      }
    }
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

  private var kindBinding: Binding<CardLogo.Kind> {
    Binding(
      get: { draft.logo.kind },
      set: { kind in
        switch kind {
        case .none: draft.logo = .none
        case .preset: draft.logo = draft.preset?.logo ?? Presets.zappka.logo
        // Empty until an image is picked; draws nothing meanwhile.
        case .custom: if draft.logo.kind != .custom { draft.logo = .custom(Data()) }
        }
      })
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
