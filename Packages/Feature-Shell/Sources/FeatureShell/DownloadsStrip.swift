import SwiftUI

/// Reserved slot for the global active-downloads strip (F5.1). The shell pins
/// this just below every tab's navigation bar. For F1.6 it renders nothing —
/// a concrete zero-height view, *not* `EmptyView`, because an `EmptyView` body
/// inside `safeAreaInset` collapses the host content to the bottom of the screen.
/// A full-width, zero-height `Color.clear` reserves the slot invisibly without
/// disturbing layout. This is also the empty state F5.1 needs: the live strip
/// hides itself when no downloads are active, so it must collapse to nothing
/// here without breaking the tab's layout.
struct DownloadsStrip: View {
  var body: some View {
    Color.clear.frame(height: 0)
  }
}
