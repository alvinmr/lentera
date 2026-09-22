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
