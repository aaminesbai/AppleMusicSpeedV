//
//  PlayerProgress.swift
//  MuzakKitApp
//
//  Created by Damien L Thompson on 2025-02-21.
//

import SwiftUI

struct PlayerProgress: View {

    @Environment(MusicPlayerService.self) var musicPlayerManager

    let duration: TimeInterval

    private var progress: TimeInterval {

        if let progress = musicPlayerManager.currentPlayBackTime,
           progress < duration {
            return max(0.0, progress)
        }

        return 0.0
    }

    private var remaining: TimeInterval {

        return -(duration) + progress
    }

    var body: some View {

        Group {

            Slider(
                value: Binding(
                    get: { progress },
                    set: { musicPlayerManager.seek(to: $0) }
                ),
                in: 0...max(duration, 1)
            )
            .accessibilityLabel("Playback Position")

            HStack {
                Text(progress, format: .duration(style: .positional))
                    .font(.caption)

                Spacer()
                Text(remaining, format: .duration(style: .positional))
                    .font(.caption)
            }
        }
    }
}
