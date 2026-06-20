import FeatureAuth
import SwiftUI

struct RootView: View {
  var body: some View {
    AuthGateView {
      SignedInPlaceholderView()
    }
  }
}
