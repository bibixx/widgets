import SwiftUI
import UIKit

extension Color {
  /// `#RRGGBB` (or `RRGGBB`); anything unparsable becomes magenta so it's obvious.
  init(hex: String) {
    guard let rgb = Self.rgb(hex: hex) else {
      self = .pink
      return
    }
    self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b)
  }

  static func rgb(hex: String) -> (r: Double, g: Double, b: Double)? {
    var s = hex.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
    return (Double((value >> 16) & 0xff) / 255, Double((value >> 8) & 0xff) / 255, Double(value & 0xff) / 255)
  }

  /// `#rrggbb` in sRGB.
  var hexString: String {
    let ui = UIColor(self)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
    return String(format: "#%02x%02x%02x", byte(r), byte(g), byte(b))
  }
}
