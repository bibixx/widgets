import SwiftUI

struct CardRow: View {
  let card: Card

  var body: some View {
    HStack(spacing: 14) {
      TimelineView(schedule) { context in
        CardView(card: card.snapshot(), family: .medium, date: context.date)
          .frame(width: 338, height: 158)
          .scaleEffect(0.3, anchor: .topLeading)
          .frame(width: 101, height: 47, alignment: .topLeading)
      }
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.quaternary) }

      VStack(alignment: .leading, spacing: 2) {
        Text(card.name).font(.headline)
        Text(card.content.kind == .zappka ? card.zappkaAccountLabel : card.rawData)
          // Żappka shows a phone number: SF Mono spaces read as gaps there.
          .font(card.content.kind == .zappka ? .subheadline.monospacedDigit() : .subheadline.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }

  /// Żappka ticks on the code switches (not 30 s from whenever the list appeared).
  private var schedule: PeriodicTimelineSchedule {
    card.content.kind == .zappka
      ? .periodic(from: Zappka.window(containing: .now).start, by: Zappka.period)
      : .periodic(from: .now, by: 3600)
  }
}
