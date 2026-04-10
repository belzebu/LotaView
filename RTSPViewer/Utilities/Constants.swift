import Foundation

enum AppConstants {
    static let maxGridSlots = 9

    static let reconnectBaseDelay: TimeInterval = 1.0
    static let reconnectMaxDelay: TimeInterval = 30.0
    static let reconnectBackoffMultiplier: Double = 2.0

    static let gridBufferDuration: Int = 200
    static let fullscreenBufferDuration: Int = 500
}

// MARK: - Grid Layout

struct GridLayout {
    let columns: Int
    let rows: Int

    static func forCount(_ count: Int) -> GridLayout {
        switch count {
        case 0, 1: return GridLayout(columns: 1, rows: 1)
        case 2:    return GridLayout(columns: 2, rows: 1)
        case 3, 4: return GridLayout(columns: 2, rows: 2)
        case 5, 6: return GridLayout(columns: 3, rows: 2)
        case 7, 8: return GridLayout(columns: 4, rows: 2)
        default:   return GridLayout(columns: 3, rows: 3)
        }
    }

    var totalSlots: Int { columns * rows }
}
