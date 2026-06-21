import SlipStreamKit
import SwiftUI

/// Request-status presentation, mirroring `web/src/lib/request-status-config.tsx`.
/// Colours are the web's Tailwind status hues; icons are SF Symbol analogues of
/// the web's lucide icons.
extension RequestStatus {
  public var statusColor: Color {
    switch self {
    case .pending: Color(hex: 0xEAB308)  // yellow-500
    case .approved: Color(hex: 0x3B82F6)  // blue-500
    case .searching: Color(hex: 0x3B82F6)  // blue-500
    case .downloading: Color(hex: 0xA855F7)  // purple-500
    case .available: Color(hex: 0x22C55E)  // green-500
    case .denied: Color(hex: 0xEF4444)  // red-500
    case .failed: Color(hex: 0xB91C1C)  // red-700
    case .cancelled: Color(hex: 0x6B7280)  // gray-500
    }
  }

  public var statusSymbol: String {
    switch self {
    case .pending: "clock"
    case .approved: "checkmark.circle"
    case .searching: "arrow.triangle.2.circlepath"
    case .downloading: "arrow.down.circle"
    case .available: "checkmark.circle.fill"
    case .denied: "xmark.circle"
    case .failed: "xmark.octagon"
    case .cancelled: "xmark.circle"
    }
  }

  public var statusLabel: String {
    switch self {
    case .pending: "Pending"
    case .approved: "Approved"
    case .searching: "Searching"
    case .downloading: "Downloading"
    case .available: "Available"
    case .denied: "Denied"
    case .failed: "Failed"
    case .cancelled: "Cancelled"
    }
  }
}

/// A pill status badge — coloured fill, white icon + label — mirroring the web
/// poster/request status badges (`rounded-4xl`, `text-white`).
public struct StatusBadge: View {
  private let status: RequestStatus

  public init(_ status: RequestStatus) {
    self.status = status
  }

  public var body: some View {
    HStack(spacing: 4) {
      Image(systemName: status.statusSymbol)
        .accessibilityHidden(true)
      Text(status.statusLabel)
    }
    .font(.ssBadge)
    .foregroundStyle(.white)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      status.statusColor, in: RoundedRectangle(cornerRadius: RadiusScale.pill, style: .continuous))
  }
}

#Preview("StatusBadge") {
  VStack(alignment: .leading, spacing: 8) {
    ForEach(RequestStatus.allCases, id: \.self) { StatusBadge($0) }
  }
  .padding()
  .background(DesignTheme.background)
}
