import SwiftUI

// MARK: - Appearance Mode

enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .system: "settings.appearance.system"
        case .light: "settings.appearance.light"
        case .dark: "settings.appearance.dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearanceMode: Int = AppearanceMode.system.rawValue
    @State private var updateChecker = UpdateChecker()

    private var currentMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dsBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        appearanceSection
                        updateSection
                        aboutSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 450)
        #endif
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.appearance")

            HStack(spacing: 8) {
                ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                    Button {
                        appearanceMode = mode.rawValue
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))
                            Text(mode.label)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(
                            mode.rawValue == appearanceMode
                                ? Color.dsPrimary
                                : Color.dsOnSurfaceVariant
                        )
                        .background(
                            mode.rawValue == appearanceMode
                                ? Color.dsPrimary.opacity(0.1)
                                : Color.dsSurfaceHigh
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    mode.rawValue == appearanceMode
                                        ? Color.dsPrimary.opacity(0.3)
                                        : Color.dsOutlineVariant.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.dsSurfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Update

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.update")

            HStack(spacing: 12) {
                Group {
                    switch updateChecker.state {
                    case .idle:
                        Label("settings.update.check", systemImage: "arrow.triangle.2.circlepath")

                    case .checking:
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("settings.update.checking")
                        }

                    case .upToDate:
                        Label("settings.update.upToDate", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.dsTertiary)

                    case .available(let version, _):
                        Label("settings.update.available \(version)", systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(Color.dsPrimary)

                    case .error:
                        Label("settings.update.error", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.dsError)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.dsOnSurface)

                Spacer()

                if case .available(_, let url) = updateChecker.state {
                    Button {
                        openURL(url)
                    } label: {
                        Text("settings.update.download")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.dsOnPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.dsPrimaryContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                if updateChecker.state == .idle || updateChecker.state == .upToDate {
                    Button {
                        Task { await updateChecker.check() }
                    } label: {
                        Text("settings.update.checkButton")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.dsPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.dsPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                if case .error = updateChecker.state {
                    Button {
                        Task { await updateChecker.check() }
                    } label: {
                        Text("settings.update.retry")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.dsOnSurfaceVariant)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.dsSurfaceHighest)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.dsSurfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("settings.about")

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dsSurfaceHighest)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text("L")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.dsPrimary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("LotaView")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dsOnSurface)
                    Text("settings.version \(version)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                }
            }

            Divider().background(Color.dsOutlineVariant.opacity(0.1))

            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
                Text("MIT License")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
            }
        }
        .padding(16)
        .background(Color.dsSurfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.dsOnSurfaceVariant)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
