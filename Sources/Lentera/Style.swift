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
