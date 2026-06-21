import SwiftUI

/// A 4-slot masked PIN entry mirroring the web portal's `InputOTP`. A single
/// hidden numeric field captures input (so paste, the number pad, and the
/// system caret all work); the visible slots render one dot per entered digit
/// and highlight the active slot while focused.
struct PINEntryField: View {
  @Binding var pin: String
  @FocusState.Binding var isFocused: Bool
  /// The PIN length is fixed at 4 (the validator in `AuthStore` and the
  /// auto-submit gate both assume it); not a configurable knob.
  private let length = 4

  var body: some View {
    ZStack {
      // Spans the whole row (masked from view) so a tap anywhere falls through
      // the non-hit-testing slots and focuses it, giving the number pad and the
      // (clear) caret a reliable target.
      TextField("", text: sanitizedPIN)
        .keyboardType(.numberPad)
        .textContentType(.none)
        .focused($isFocused)
        .foregroundStyle(.clear)
        .tint(.clear)
        .frame(maxWidth: .infinity, minHeight: 56)
        .accessibilityLabel("PIN")

      HStack(spacing: 12) {
        ForEach(0..<length, id: \.self) { index in
          slot(at: index)
        }
      }
      .allowsHitTesting(false)
    }
    .frame(maxWidth: .infinity)
  }

  /// Filters input to digits and caps it at `length`, so the number pad and any
  /// paste both stay within bounds.
  private var sanitizedPIN: Binding<String> {
    Binding(
      get: { pin },
      set: { pin = String($0.filter(\.isNumber).prefix(length)) }
    )
  }

  private func slot(at index: Int) -> some View {
    let isFilled = index < pin.count
    let isActive = isFocused && index == min(pin.count, length - 1) && pin.count < length
    return RoundedRectangle(cornerRadius: 10)
      .fill(Color(.secondarySystemBackground))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(
            isActive ? Color.accentColor : Color.secondary.opacity(0.35),
            lineWidth: isActive ? 2 : 1
          )
      )
      .overlay {
        if isFilled {
          Circle().fill(Color.primary).frame(width: 12, height: 12)
        }
      }
      .frame(width: 48, height: 56)
  }
}
