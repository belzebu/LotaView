import Foundation

enum StreamStatus: Equatable {
    case idle
    case connecting
    case playing
    case error(String)
    case stopped

    var isActive: Bool {
        switch self {
        case .connecting, .playing:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return String(localized: "status.ready")
        case .connecting:
            return String(localized: "status.connecting")
        case .playing:
            return String(localized: "status.playing")
        case .error(let message):
            return "\(String(localized: "status.error")): \(message)"
        case .stopped:
            return String(localized: "status.stopped")
        }
    }
}
