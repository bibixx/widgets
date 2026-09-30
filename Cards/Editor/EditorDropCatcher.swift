import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Accepts an image dropped anywhere on screen while the editor is open (e.g. a screenshot
/// dragged from its thumbnail).
///
/// Views inside the sheet (the Form's collection view, SwiftUI's hosting views) claim drags
/// and refuse images, so no handler inside the app's window reliably sees them. Instead, a
/// transparent window floats above everything while the editor is open, with one drop
/// target covering the screen. It ignores real touches (taps, scrolls and typing go to the
/// app underneath) and only answers UIKit's drop-target hit test (see `isDropHitTest`).
struct EditorDropCatcher: UIViewRepresentable {
  @Binding var isTargeted: Bool
  let onDrop: @MainActor (Data) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIView(context: Context) -> AnchorView {
    let view = AnchorView()
    view.isUserInteractionEnabled = false
    view.coordinator = context.coordinator
    return view
  }

  func updateUIView(_ view: AnchorView, context: Context) {
    context.coordinator.parent = self
  }

  static func dismantleUIView(_ view: AnchorView, coordinator: Coordinator) {
    view.removeOverlay()
  }

  /// Zero-size view in the editor; shows the overlay window while it's on screen.
  final class AnchorView: UIView {
    weak var coordinator: Coordinator?
    private var overlay: DropWindow?

    override func didMoveToWindow() {
      super.didMoveToWindow()
      guard let scene = window?.windowScene, let coordinator else {
        removeOverlay()
        return
      }
      guard overlay == nil else { return }
      let overlay = DropWindow(windowScene: scene)
      overlay.windowLevel = .alert + 1
      overlay.backgroundColor = .clear
      let controller = UIViewController()
      controller.view = DropTargetView()
      controller.view.backgroundColor = .clear
      controller.view.addInteraction(UIDropInteraction(delegate: coordinator))
      overlay.rootViewController = controller
      overlay.isHidden = false
      self.overlay = overlay
    }

    func removeOverlay() {
      overlay?.isHidden = true
      overlay = nil
    }
  }

  /// Never becomes key and never takes real touches.
  final class DropWindow: UIWindow {
    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      let hit = super.hitTest(point, with: event)
      return hit === self ? nil : hit
    }
  }

  /// Covers the screen for drop hit tests only; any real interaction passes through.
  final class DropTargetView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      Self.isDropHitTest(event) ? super.hitTest(point, with: event) : nil
    }

    /// UIKit's drop-target hit test arrives with a `UIDragEvent` (private class). Taps arrive
    /// as `UITouchesEvent`, whose touches aren't attached yet at hit-test time, so the event
    /// class is the only reliable tell.
    static func isDropHitTest(_ event: UIEvent?) -> Bool {
      guard let event else { return false }
      return NSStringFromClass(type(of: event)).localizedCaseInsensitiveContains("drag")
    }
  }

  final class Coordinator: NSObject, UIDropInteractionDelegate {
    var parent: EditorDropCatcher
    init(_ parent: EditorDropCatcher) { self.parent = parent }

    private func setTargeted(_ targeted: Bool) {
      if parent.isTargeted != targeted { parent.isTargeted = targeted }
    }

    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
      session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier])
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
      UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) { setTargeted(true) }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) { setTargeted(false) }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) { setTargeted(false) }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
      setTargeted(false)
      guard let provider = session.items.first(where: {
        $0.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
      })?.itemProvider else { return }
      let onDrop = parent.onDrop
      _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
        guard let data else { return }
        Task { @MainActor in onDrop(data) }
      }
    }
  }
}
