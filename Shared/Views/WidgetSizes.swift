import CoreGraphics
import UIKit

/// Real Home Screen widget sizes (points) by screen size, so previews are pixel-true.
/// Known values; unknown screens fall back to the iPhone 13 Pro sizes.
/// TODO(stage 8): confirm on the user's device with Home Screen screenshots.
struct WidgetSizes: Sendable {
  var small: CGSize
  var medium: CGSize
  var large: CGSize

  static let fallback = WidgetSizes(small: 158, medium: 338, large: 354)

  init(small: CGFloat, medium: CGFloat, large: CGFloat) {
    self.small = CGSize(width: small, height: small)
    self.medium = CGSize(width: medium, height: small)
    self.large = CGSize(width: medium, height: large)
  }

  /// Keyed by portrait screen size in points.
  static let table: [String: WidgetSizes] = [
    "440x956": .init(small: 170, medium: 364, large: 382),  // 16/17 Pro Max
    "430x932": .init(small: 170, medium: 364, large: 382),  // 14/15 Pro Max, Plus
    "428x926": .init(small: 170, medium: 364, large: 382),  // 12/13 Pro Max
    "414x896": .init(small: 169, medium: 360, large: 379),  // 11, XR, 11 Pro Max
    "402x874": .init(small: 164.33, medium: 349.67, large: 365),  // 16/17 Pro (measured, simulator)
    "393x852": .init(small: 158, medium: 338, large: 354),  // 14 Pro, 15, 15 Pro, 16
    "390x844": .init(small: 158, medium: 338, large: 354),  // 12, 13, 14
    "375x812": .init(small: 155, medium: 329, large: 345),  // mini, X, XS
    "375x667": .init(small: 148, medium: 321, large: 324),  // SE
  ]

  @MainActor static var current: WidgetSizes {
    let bounds = UIScreen.main.bounds.size
    let w = Int(min(bounds.width, bounds.height)), h = Int(max(bounds.width, bounds.height))
    return table["\(w)x\(h)"] ?? fallback
  }

  func size(for family: CardFamily) -> CGSize {
    switch family {
    case .small: small
    case .medium: medium
    case .large: large
    }
  }
}
