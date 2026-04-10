import Foundation
import SwiftData

@Model
final class Dashboard {
    var id: UUID
    var name: String
    var cameraIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(name: String, cameraIDs: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.cameraIDs = cameraIDs
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func addCamera(_ camera: Camera) {
        guard !cameraIDs.contains(camera.id) else { return }
        cameraIDs.append(camera.id)
        updatedAt = Date()
    }

    func removeCamera(_ camera: Camera) {
        cameraIDs.removeAll { $0 == camera.id }
        updatedAt = Date()
    }

    func setCameras(_ cameras: [Camera]) {
        cameraIDs = cameras.map(\.id)
        updatedAt = Date()
    }

    func cameras(from allCameras: [Camera]) -> [Camera] {
        cameraIDs.compactMap { id in
            allCameras.first { $0.id == id }
        }
    }
}
