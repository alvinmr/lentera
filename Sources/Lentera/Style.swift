import SwiftUI

extension View {
  @ViewBuilder
  func lenteraSurface(cornerRadius: CGFloat = 12) -> some View {
    if #available(macOS 26.0, *) {
      glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    } else {
      background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Color(nsColor: .separatorColor))
        }
    }
  }

  @ViewBuilder
  func lenteraButton() -> some View {
    if #available(macOS 26.0, *) {
      buttonStyle(.glass)
    } else {
      buttonStyle(.bordered)
    }
  }

  @ViewBuilder
  func lenteraProminentButton() -> some View {
    if #available(macOS 26.0, *) {
      buttonStyle(.glassProminent)
    } else {
      buttonStyle(.borderedProminent)
    }
  }
}

enum Motion {
  /// Strong ease-out for things that enter or leave: cubic-bezier(0.23, 1, 0.32, 1).
  static func easeOut(_ duration: Double) -> Animation {
    .timingCurve(0.23, 1, 0.32, 1, duration: duration)
  }

  /// CSS `ease`, for hover changes.
  static let hover = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.15)
  static let press = Animation.easeOut(duration: 0.12)
  /// Apple-style spring, kept for rare moments such as a new book landing on the shelf.
  static let settle = Animation.spring(duration: 0.5, bounce: 0.2)

  /// Fades and grows from slightly smaller; only fades when Reduce Motion is on.
  static func appear(reduceMotion: Bool, scale: CGFloat = 0.97, anchor: UnitPoint = .center)
    -> AnyTransition
  {
    reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: scale, anchor: anchor))
  }
}

/// A small capsule label, such as a book's format.
struct Tag: View {
  private let content: Text
  private let tint: Color?

  init(text: String, tint: Color? = nil) {
    content = Text(text)
    self.tint = tint
  }

  init(symbol: String, tint: Color? = nil) {
    content = Text(Image(systemName: symbol))
    self.tint = tint
  }

  var body: some View {
    content
      .font(.caption2.weight(.semibold))
      .foregroundStyle(tint ?? .secondary)
      .padding(.horizontal, 6).padding(.vertical, 1)
      .background(tint.map { AnyShapeStyle($0.opacity(0.18)) } ?? AnyShapeStyle(.quaternary), in: Capsule())
      .lineLimit(1)
  }
}
