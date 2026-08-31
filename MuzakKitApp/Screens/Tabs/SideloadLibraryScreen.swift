//
//  SideloadLibraryScreen.swift
//  MuzakKitApp
//
//  Created for free sideload library playback.
//

import MediaPlayer
import SwiftUI

struct SideloadLibraryScreen: View {

    @Environment(SideloadMusicPlayerService.self) private var sideloadPlayer

    @State private var selection: SideloadLibrarySelection = .albums

    var body: some View {
        @Bindable var sideloadPlayer = sideloadPlayer

        List {
            Section {
                Picker("Library", selection: $selection) {
                    ForEach(SideloadLibrarySelection.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .plainHeaderStyle()

            if let nowPlayingItem = sideloadPlayer.nowPlayingItem {
                Section("Now Playing") {
                    SideloadTrackRow(item: nowPlayingItem)

                    HStack {
                        Button {
                            sideloadPlayer.skipToPrevious()
                        } label: {
                            Symbols.skipBack.image
                        }

                        Spacer()

                        Button {
                            sideloadPlayer.togglePlayback()
                        } label: {
                            Image(systemName: sideloadPlayer.playbackState == .playing ? Symbols.pause.name : Symbols.play.name)
                                .font(.title2)
                        }

                        Spacer()

                        Button {
                            sideloadPlayer.skipToNext()
                        } label: {
                            Symbols.skipForward.image
                        }
                    }
                    .buttonStyle(.borderless)
                    .padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Button {
                                sideloadPlayer.resetPlaybackRate()
                            } label: {
                                Text(Self.formatRate(sideloadPlayer.preferredPlaybackRate))
                                    .monospacedDigit()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reset Playback Speed")
                        }

                        Slider(
                            value: Binding(
                                get: { Double(sideloadPlayer.preferredPlaybackRate) },
                                set: { sideloadPlayer.setPreferredPlaybackRate(Float($0)) }
                            ),
                            in: Double(SideloadMusicPlayerService.minimumPlaybackRate)...Double(SideloadMusicPlayerService.maximumPlaybackRate),
                            step: 0.05
                        )
                        .accessibilityLabel("Playback Speed")
                        .accessibilityValue("\(Self.formatRateForAccessibility(sideloadPlayer.preferredPlaybackRate)) times")

                        HStack {
                            Text("0.5×")
                            Spacer()
                            Text("2.0×")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let message = sideloadPlayer.playbackRateMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            switch selection {
            case .albums:
                albumsSection
            case .playlists:
                playlistsSection
            case .songs:
                songsSection
            }
        }
        .navigationTitle("Sideload")
        .task {
            sideloadPlayer.requestAuthorizationIfNeeded()
        }
        .refreshable {
            sideloadPlayer.reloadLibrary()
        }
    }

    private var albumsSection: some View {
        Section("Albums") {
            if sideloadPlayer.albums.isEmpty {
                ContentUnavailableView("No Albums", systemImage: Symbols.squareStack.name)
            } else {
                ForEach(Array(sideloadPlayer.albums.enumerated()), id: \.offset) { _, album in
                    NavigationLink {
                        SideloadCollectionDetailView(
                            title: album.representativeItem?.albumTitle ?? "Album",
                            subtitle: album.representativeItem?.albumArtist ?? album.representativeItem?.artist,
                            items: album.items
                        )
                    } label: {
                        SideloadTrackRow(item: album.representativeItem)
                    }
                }
            }
        }
    }

    private var playlistsSection: some View {
        Section("Playlists") {
            if sideloadPlayer.playlists.isEmpty {
                ContentUnavailableView("No Playlists", systemImage: Symbols.musicNoteList.name)
            } else {
                ForEach(Array(sideloadPlayer.playlists.enumerated()), id: \.offset) { _, playlist in
                    NavigationLink {
                        SideloadCollectionDetailView(
                            title: playlist.name ?? "Playlist",
                            subtitle: "\(playlist.items.count) songs",
                            items: playlist.items
                        )
                    } label: {
                        HStack {
                            Symbols.musicNoteList.image
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(width: 48, height: 48)

                            VStack(alignment: .leading) {
                                Text(playlist.name ?? "Playlist")
                                    .lineLimit(1)
                                Text("\(playlist.items.count) songs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var songsSection: some View {
        Section("Songs") {
            if sideloadPlayer.songs.isEmpty {
                ContentUnavailableView("No Songs", systemImage: Symbols.musicNoteList.name)
            } else {
                ForEach(Array(sideloadPlayer.songs.enumerated()), id: \.offset) { _, song in
                    Button {
                        sideloadPlayer.play(song, from: sideloadPlayer.songs)
                    } label: {
                        SideloadTrackRow(item: song)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private static func formatRate(_ rate: Float) -> String {
        String(format: "%.2f×", rate)
    }

    private static func formatRateForAccessibility(_ rate: Float) -> String {
        String(format: "%.2f", rate)
    }
}

private enum SideloadLibrarySelection: CaseIterable, Identifiable {

    case albums
    case playlists
    case songs

    var id: Self { self }

    var title: String {
        switch self {
        case .albums: "Albums"
        case .playlists: "Playlists"
        case .songs: "Songs"
        }
    }
}

private struct SideloadCollectionDetailView: View {

    @Environment(SideloadMusicPlayerService.self) private var sideloadPlayer

    let title: String
    let subtitle: String?
    let items: [MPMediaItem]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let subtitle {
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .plainHeaderStyle()

            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Button {
                        sideloadPlayer.play(item, from: items)
                    } label: {
                        SideloadTrackRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SideloadTrackRow: View {

    let item: MPMediaItem?

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 3) {
                Text(item?.title ?? item?.albumTitle ?? "Unknown Title")
                    .lineLimit(1)

                Text(item?.artist ?? item?.albumArtist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = item?.artwork?.image(at: CGSize(width: 48, height: 48)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Symbols.albumPlaceholder.image
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
