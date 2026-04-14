import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CameraFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let camera: Camera?
    let viewModel: CameraManagerViewModel

    @State private var name = ""
    @State private var rtspURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var validationError: String?
    @State private var copiedToClipboard = false

    private var isEditing: Bool { camera != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Form fields
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cameraNameField
                    rtspURLField
                    credentialsSection
                    configActions
                    infoNote
                }
                .padding(24)
            }

            // Footer buttons
            footerSection
        }
        .background(Color.dsSurfaceHigh.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.dsOutlineVariant.opacity(0.2), lineWidth: 1)
        )
        .frame(maxWidth: 480)
        .padding(24)
        .background(Color.dsOnSurface.opacity(0.3).ignoresSafeArea())
        .onAppear { loadCamera() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? String(localized: "form.title.edit") : String(localized: "form.title.add"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.dsOnSurface)

                Text("form.subtitle")
                    .font(.caption)
                    .foregroundStyle(Color.dsOnSurfaceVariant)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
                    .padding(8)
                    .background(Color.dsSurfaceBright.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    // MARK: - Camera Name

    private var cameraNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(String(localized: "camera.name"))
            TextField(String(localized: "camera.name.placeholder"), text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.dsSurfaceHighest)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Color.dsOnSurface)
        }
    }

    // MARK: - RTSP URL

    private var rtspURLField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(String(localized: "camera.rtspURL"))
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsOnSurfaceVariant)

                TextField("rtsp://192.168.1.100:554/live", text: $rtspURL)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.dsOnSurface)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    #endif
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color.dsSurfaceHighest)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Credentials

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().background(Color.dsOutlineVariant.opacity(0.1))

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsPrimary)
                Text("camera.auth")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsOnSurface)
            }

            HStack(spacing: 12) {
                // Username
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(String(localized: "camera.username"))
                    TextField("admin", text: $username)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.dsSurfaceHighest)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.dsOnSurface)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                }

                // Password
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(String(localized: "camera.password"))
                    HStack {
                        Group {
                            if showPassword {
                                TextField("password", text: $password)
                            } else {
                                SecureField("password", text: $password)
                            }
                        }
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.dsOnSurface)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()

                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dsOnSurfaceVariant)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.dsSurfaceHighest)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Copy / Paste Config

    private var configActions: some View {
        HStack(spacing: 8) {
            if isEditing {
                Button(action: copyConfig) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                        Text(copiedToClipboard
                             ? String(localized: "form.copied")
                             : String(localized: "form.copyConfig"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.dsOnSurfaceVariant)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.dsSurfaceBright)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Button(action: pasteConfig) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                    Text("form.pasteConfig")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.dsOnSurfaceVariant)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.dsSurfaceBright)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Info Note

    private var infoNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 16))
                .foregroundStyle(Color.dsPrimary)

            Text("form.networkNote")
                .font(.system(size: 12))
                .foregroundStyle(Color.dsOnSurfaceVariant)
                .lineSpacing(2)
        }
        .padding(12)
        .background(Color.dsBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.dsOutlineVariant.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Validation Error

    @ViewBuilder
    private var validationErrorView: some View {
        if let error = validationError {
            Text(error)
                .font(.caption)
                .foregroundStyle(Color.dsError)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            validationErrorView

            HStack(spacing: 12) {
                Spacer()

                Button("action.cancel") { dismiss() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .buttonStyle(.plain)

                Button(action: save) {
                    Text("camera.save")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.dsOnPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.dsPrimary, Color.dsPrimaryContainer],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.dsPrimaryContainer.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty || rtspURL.isEmpty)
                .opacity(name.isEmpty || rtspURL.isEmpty ? 0.5 : 1)
            }
            .padding(24)
        }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.dsOnSurfaceVariant)
    }

    private func loadCamera() {
        guard let camera else { return }
        name = camera.name
        rtspURL = camera.rtspURL
        if let creds = camera.credentials {
            username = creds.username
            password = creds.password
        }
    }

    private func pasteURL() {
        guard let clip = readClipboard() else { return }
        rtspURL = clip
    }

    private func copyConfig() {
        let maskedPassword = password.isEmpty ? "" : "****"
        let config = [
            "Name: \(name)",
            "URL: \(rtspURL)",
            "Username: \(username)",
            "Password: \(maskedPassword)",
        ].joined(separator: "\n")
        writeClipboard(config)
        copiedToClipboard = true
    }

    private func pasteConfig() {
        guard let clipboard = readClipboard() else { return }
        for line in clipboard.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "name": name = value
            case "url": rtspURL = value
            case "username": username = value
            case "password": password = value
            default: break
            }
        }
    }

    private func readClipboard() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #endif
    }

    private func writeClipboard(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = rtspURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { validationError = String(localized: "validation.nameRequired"); return }
        guard !trimmedURL.isEmpty else { validationError = String(localized: "validation.urlRequired"); return }
        guard trimmedURL.lowercased().hasPrefix("rtsp://") else { validationError = String(localized: "validation.urlInvalid"); return }

        if let camera {
            viewModel.updateCamera(camera, name: trimmedName, rtspURL: trimmedURL, username: username, password: password)
        } else {
            viewModel.addCamera(name: trimmedName, rtspURL: trimmedURL, username: username, password: password)
        }
        dismiss()
    }
}
