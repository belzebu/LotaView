import SwiftUI

struct CameraPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let cameras: [Camera]
    let onSelect: (Camera) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dsBackground.ignoresSafeArea()

                if cameras.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.3))
                        Text("camera.none")
                            .font(.headline)
                            .foregroundStyle(Color.dsOnSurface)
                        Text("camera.none.pickerHint")
                            .font(.caption)
                            .foregroundStyle(Color.dsOnSurfaceVariant)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(cameras, id: \.id) { camera in
                                Button {
                                    onSelect(camera)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.dsPrimary)
                                            .frame(width: 32, height: 32)
                                            .background(Color.dsSurfaceHighest)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(camera.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.dsOnSurface)
                                            Text(camera.rtspURL)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(Color.dsOnSurfaceVariant)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.5))
                                    }
                                    .padding(12)
                                    .background(Color.dsSurfaceHigh.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(String(localized: "camera.select"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
            }
        }
    }
}
