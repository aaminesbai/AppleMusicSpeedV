//
//  PlaybackSpeedControl.swift
//  MuzakKitApp
//
//  Created by OpenAI on 2026-08-31.
//

import SwiftUI

struct PlaybackSpeedControl: View {

    @Environment(MusicPlayerService.self) private var musicPlayer
    @Environment(\.haptics) private var haptics

    private var playbackSpeedBinding: Binding<Double> {
        Binding {
            Double(musicPlayer.preferredPlaybackRate)
        } set: { value in
            musicPlayer.setPreferredPlaybackRate(Float(value))
        }
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {
            header
            speedSlider

            if let message = musicPlayer.playbackRateMessage {
                Label(message, systemImage: Symbols.warning.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - View Builders
extension PlaybackSpeedControl {

    private var header: some View {

        HStack {
            Text("Speed")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Button {
                haptics.impact(.light)
                musicPlayer.resetPlaybackRate()
            } label: {
                Text(formattedSpeed(musicPlayer.preferredPlaybackRate))
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset Playback Speed")
            .accessibilityValue("Normal speed")
        }
    }

    private var speedSlider: some View {

        VStack(spacing: 4) {
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
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers
extension PlaybackSpeedControl {

    private func formattedSpeed(_ speed: Float) -> String {
        return String(format: "%.2f×", Double(speed))
    }

    private func accessibilitySpeedValue(_ speed: Float) -> String {
        return String(format: "%.2f times", Double(speed))
    }
}
