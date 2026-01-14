import SwiftUI

/// Settings view for configuring video and audio quality preferences
struct SettingsView: View {
    @ObservedObject private var qualitySettings = QualitySettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Video Quality Section
                        qualitySection(
                            title: "Video Quality",
                            icon: "play.rectangle.fill",
                            selection: Binding(
                                get: { qualitySettings.videoQuality },
                                set: { qualitySettings.videoQuality = $0 }
                            ),
                            options: VideoQuality.allCases
                        ) { quality in
                            HStack {
                                Image(systemName: quality.icon)
                                    .foregroundStyle(Theme.primaryGradient)
                                    .frame(width: 24)
                                Text(quality.displayName)
                                Spacer()
                                if quality == qualitySettings.videoQuality {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        
                        // Audio Quality Section
                        qualitySection(
                            title: "Audio Quality",
                            icon: "speaker.wave.3.fill",
                            selection: Binding(
                                get: { qualitySettings.audioQuality },
                                set: { qualitySettings.audioQuality = $0 }
                            ),
                            options: AudioQuality.allCases
                        ) { quality in
                            HStack {
                                Image(systemName: quality.icon)
                                    .foregroundStyle(Theme.primaryGradient)
                                    .frame(width: 24)
                                Text(quality.displayName)
                                Spacer()
                                if quality == qualitySettings.audioQuality {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        
                        // Info Card
                        infoCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.primaryGradient)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // MARK: - Components
    
    private func qualitySection<T: Identifiable & Hashable>(
        title: String,
        icon: String,
        selection: Binding<T>,
        options: [T],
        @ViewBuilder row: @escaping (T) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.primaryGradient)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // Options
            VStack(spacing: 0) {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        row(option)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    
                    if option.id as AnyHashable != options.last?.id as AnyHashable {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Theme.accent)
                Text("About Quality Settings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            Text("Higher quality requires more bandwidth and storage. If the selected quality is unavailable, the closest available quality will be used automatically.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.accent.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
