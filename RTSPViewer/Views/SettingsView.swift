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

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.language")

            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dsPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.language.current")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.dsOnSurface)

                    Text("settings.language.hint")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                }
            }

            #if os(iOS)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("settings.language.openSettings")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.dsPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.dsPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            #endif
        }
        .sentinelCard()
        .padding(16)
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
