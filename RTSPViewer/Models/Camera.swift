import Foundation
import SwiftData

@Model
final class Camera {
    var id: UUID
    var name: String
    var rtspURL: String
    var gridPosition: Int
    var createdAt: Date
    var updatedAt: Date

    // Store credentials directly in SwiftData (simpler, no Keychain popup on macOS)
    var storedUsername: String
    var storedPassword: String

    init(
        name: String,
        rtspURL: String,
        username: String = "",
        password: String = ""
    ) {
        let id = UUID()
        self.id = id
        self.name = name
        self.rtspURL = rtspURL
        self.gridPosition = -1
        self.createdAt = Date()
        self.updatedAt = Date()
        self.storedUsername = username
        self.storedPassword = password
    }

    var credentials: (username: String, password: String)? {
        guard !storedUsername.isEmpty else { return nil }
        return (storedUsername, storedPassword)
    }

    var authenticatedURL: String {
        guard !storedUsername.isEmpty,
              var components = URLComponents(string: rtspURL) else {
            return rtspURL
        }
        components.user = storedUsername
        components.password = storedPassword
        return components.string ?? rtspURL
    }

    func updateCredentials(username: String, password: String) {
        storedUsername = username
        storedPassword = password
        updatedAt = Date()
    }

    func deleteCredentials() {
        storedUsername = ""
        storedPassword = ""
    }
}
