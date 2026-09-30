import Foundation
import Testing
import UIKit
@testable import Cards

@MainActor
struct CodeImporterTests {
  static func png(_ text: String, _ symbology: Symbology) throws -> Data {
    let matrix = try BarcodeRenderer.matrix(for: text, symbology: symbology)
    let image = try #require(BarcodeRenderer.upscaled(matrix, moduleSize: 6, linearHeight: 160))
    return try #require(UIImage(cgImage: image).pngData())
  }

  @Test func droppedBarcodeFillsNumberAndType() async throws {
    let draft = EditorDraft(preset: Presets.custom)
    draft.symbology = .qr
    let importer = CodeImporter()
    await importer.importImage(try Self.png("0491118882945", .code128), into: draft)
    #expect(draft.rawData == "0491118882945")
    #expect(draft.symbology == .code128)
    #expect(importer.failure == nil)
  }

  @Test func droppedZappkaCodeFillsUserId() async throws {
    let draft = EditorDraft(preset: Presets.zappka)
    let importer = CodeImporter()
    let payload = Zappka.payload(userId: "1234567", code: "000042")
    await importer.importImage(try Self.png(payload, .pdf417), into: draft)
    #expect(draft.zappkaUserId == "1234567")
    #expect(importer.failure == nil)
  }

  @Test func nonZappkaCodeOnZappkaCardFails() async throws {
    let draft = EditorDraft(preset: Presets.zappka)
    let importer = CodeImporter()
    await importer.importImage(try Self.png("12345678", .code128), into: draft)
    #expect(draft.zappkaUserId.isEmpty)
    #expect(importer.failure != nil)
  }

  @Test func imageWithoutCodeFails() async throws {
    let blank = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).pngData { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
    }
    let draft = EditorDraft(preset: Presets.custom)
    let importer = CodeImporter()
    await importer.importImage(blank, into: draft)
    #expect(importer.failure != nil)
    #expect(draft.rawData.isEmpty)
  }

  @Test func zappkaUserIdParsing() {
    #expect(Zappka.userId(fromPayload: "https://srln.pl/view/dashboard?ploy=abc_1&loyal=123456") == "abc_1")
    #expect(Zappka.userId(fromPayload: "https://zlgn.pl/view/dashboard?ploy=42&loyal=1") == "42")
    #expect(Zappka.userId(fromPayload: "https://example.com/?ploy=42") == nil)
    #expect(Zappka.userId(fromPayload: "5901234123457") == nil)
  }
}
