import SwiftUI
import FeatureAuth

struct RootView: View {
    var body: some View {
        AuthGateView {
            SignedInPlaceholderView()
        }
    }
}
