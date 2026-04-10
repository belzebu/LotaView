import SwiftUI
import SwiftData

@Observable
final class CameraManagerViewModel {
    var cameras: [Camera] = []
    var editingCamera: Camera?
    var showingForm = false
    var showingDeleteConfirmation = false
    var cameraToDelete: Camera?

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchCameras()
    }

    func fetchCameras() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Camera>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        cameras = (try? context.fetch(descriptor)) ?? []
    }

    func addCamera(name: String, rtspURL: String, username: String, password: String) {
        guard let context = modelContext else { return }

        let camera = Camera(
            name: name,
            rtspURL: rtspURL,
            username: username,
            password: password
        )
        context.insert(camera)
        saveAndRefresh()
    }

    func updateCamera(_ camera: Camera, name: String, rtspURL: String, username: String, password: String) {
        camera.name = name
        camera.rtspURL = rtspURL
        camera.updateCredentials(username: username, password: password)
        saveAndRefresh()
    }

    func deleteCamera(_ camera: Camera) {
        guard let context = modelContext else { return }
        camera.deleteCredentials()
        context.delete(camera)
        saveAndRefresh()
    }

    func confirmDelete(_ camera: Camera) {
        cameraToDelete = camera
        showingDeleteConfirmation = true
    }

    func performDelete() {
        guard let camera = cameraToDelete else { return }
        deleteCamera(camera)
        cameraToDelete = nil
    }

    func startEditing(_ camera: Camera) {
        editingCamera = camera
        showingForm = true
    }

    func startAdding() {
        editingCamera = nil
        showingForm = true
    }

    private func saveAndRefresh() {
        try? modelContext?.save()
        fetchCameras()
    }
}
