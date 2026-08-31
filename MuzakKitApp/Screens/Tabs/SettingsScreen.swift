//
//  SettingsScreen.swift
//  MuzakKitApp
//
//  Created by OpenAI on 2026-08-31.
//

import SwiftUI

struct SettingsScreen: View {

    @Environment(MusicPlayerService.self) private var musicPlayer
    @Environment(\.haptics) private var haptics

    private var playbackSpeedBinding: Binding<Double> {
        Binding {
            Double(musicPlayer.preferredPlaybackRate)
        } set: { value in
            musicPlayer.setPreferredPlaybackRate(Float(value))
        }
    }

    private var rememberPlaybackSpeedBinding: Binding<Bool> {
        Binding {
            musicPlayer.rememberPlaybackSpeed
        } set: { value in
            musicPlayer.setRememberPlaybackSpeed(value)
        }
    }

    var body: some View {

        Form {
            Section("Playback") {
                defaultSpeedControl

                Toggle("Remember Playback Speed", isOn: rememberPlaybackSpeedBinding)

                Button {
                    haptics.impact(.light)
                    musicPlayer.resetPlaybackRate()
                } label: {
                    Label("Reset Playback Speed", systemImage: Symbols.checkMarkCircle.name)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - View Builders
extension SettingsScreen {

    private var defaultSpeedControl: some View {

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Default Speed")
                Spacer()
                Text(formattedSpeed(musicPlayer.preferredPlaybackRate))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: playbackSpeedBinding,
                in: Double(MusicPlayerService.minimumPlaybackRate)...Double(MusicPlayerService.maximumPlaybackRate),
                step: 0.05
            )
            .accessibilityLabel("Playback Speed")
            .accessibilityValue(accessibilitySpeedValue(musicPlayer.preferredPlaybackRate))

            HStack {
                Text(formattedSpeed(MusicPlayerService.minimumPlaybackRate))
                Spacer()
                Text(formattedSpeed(MusicPlayerService.maximumPlaybackRate))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers
extension SettingsScreen {

    private func formattedSpeed(_ speed: Float) -> String {
        return String(format: "%.2f×", Double(speed))
    }

    private func accessibilitySpeedValue(_ speed: Float) -> String {
        return String(format: "%.2f times", Double(speed))
    }
}
