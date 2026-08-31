//
//  LocalMediaLibraryScreen.swift
//  MuzakKitApp
//
//  Created for free MediaPlayer library playback.
//

import MediaPlayer
import SwiftUI

struct LocalMediaLibraryScreen: View {

    @Environment(MusicPlayerService.self) private var musicPlayer

    let section: LocalLibrarySection

    var body: some View {
        List {
            switch section {
            case .songs:
                songsSection(musicPlayer.localSongs)
            case .playlists:
                playlistSection
            case .albums, .artists, .genres:
                collectionSection(musicPlayer.localCollections(for: section))
            }
        }
        .navigationTitle(section.title)
        .task {
            musicPlayer.requestLocalLibraryAuthorizationIfNeeded()
        }
        .refreshable {
            musicPlayer.reloadLocalLibrary()
        }
    }

    @ViewBuilder
    private func collectionSection(_ collections: [MPMediaItemCollection]) -> some View {

        if collections.isEmpty {
            ContentUnavailableView("No \(section.title)", systemImage: Symbols.musicNoteList.name)
        } else {
            ForEach(Array(collections.enumerated()), id: \.offset) { _, collection in
                NavigationLink {
                    LocalMediaCollectionDetailScreen(
                        title: title(for: collection),
                        subtitle: subtitle(for: collection),
                        items: sortedItems(for: collection)
                    )
                } label: {
                    LocalMediaCollectionRow(
                        title: title(for: collection),
                        subtitle: subtitle(for: collection),
                        item: collection.representativeItem
                    )
                }
            }
        }
    }

    private var playlistSection: some View {
        Group {
            if musicPlayer.localPlaylists.isEmpty {
                ContentUnavailableView("No Playlists", systemImage: Symbols.musicNoteList.name)
            } else {
                ForEach(musicPlayer.localPlaylists, id: \.persistentID) { playlist in
                    NavigationLink {
                        LocalMediaCollectionDetailScreen(
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

                            VStack(alignment: .leading, spacing: 3) {
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

    @ViewBuilder
    private func songsSection(_ songs: [MPMediaItem]) -> some View {

        if songs.isEmpty {
            ContentUnavailableView("No Songs", systemImage: Symbols.musicNoteList.name)
        } else {
            ForEach(songs, id: \.persistentID) { item in
                Button {
                    musicPlayer.playLocalItem(item, from: songs)
                } label: {
                    LocalMediaItemRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func title(for collection: MPMediaItemCollection) -> String {

        switch section {
        case .albums:
            collection.representativeItem?.albumTitle ?? "Album"
        case .artists:
            collection.representativeItem?.artist ?? "Artist"
        case .genres:
            collection.representativeItem?.genre ?? "Genre"
        case .playlists, .songs:
            collection.representativeItem?.title ?? "Songs"
        }
    }

    private func subtitle(for collection: MPMediaItemCollection) -> String? {

        switch section {
        case .albums:
            collection.representativeItem?.albumArtist ?? collection.representativeItem?.artist
        case .artists, .genres:
            "\(collection.items.count) songs"
        case .playlists, .songs:
            nil
        }
    }

    private func sortedItems(for collection: MPMediaItemCollection) -> [MPMediaItem] {

        switch section {
        case .albums:
            collection.items.sorted {
                if $0.discNumber != $1.discNumber {
                    return $0.discNumber < $1.discNumber
                }

                return $0.albumTrackNumber < $1.albumTrackNumber
            }
        case .artists, .genres, .playlists, .songs:
            collection.items
        }
    }
}

private struct LocalMediaCollectionDetailScreen: View {

    @Environment(MusicPlayerService.self) private var musicPlayer

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

            ForEach(items, id: \.persistentID) { item in
                Button {
                    musicPlayer.playLocalItem(item, from: items)
                } label: {
                    LocalMediaItemRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LocalMediaItemRow: View {

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

private struct LocalMediaCollectionRow: View {

    let title: String
    let subtitle: String?
    let item: MPMediaItem?

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
