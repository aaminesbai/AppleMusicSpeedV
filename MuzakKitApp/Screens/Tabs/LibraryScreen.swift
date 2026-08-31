//
//  LibraryScreen.swift
//  MuzakKitApp
//
//  Created by Damien L Thompson on 2025-01-06.
//

import SwiftUI

struct LibraryScreen: View {

    @Environment(MusicPlayerService.self) private var musicPlayer

    var body: some View {

        List {
            ForEach(
                AppRootScreen.LibraryList.allCases,
                id: \.id
            ) { item in

                NavigationLink(value: item) {
                    HStack {
                        Image(systemName: item.icon)
                            .frame(minWidth: 30)
                            .imageScale(.large)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                        Text(item.title).font(.title2)
                    }
                }
            }

            Section("Recently Added") {
                if musicPlayer.recentlyAddedSongs.isEmpty {
                    ContentUnavailableView("No Recent Songs", systemImage: Symbols.musicNoteList.name)
                } else {
                    ForEach(musicPlayer.recentlyAddedSongs, id: \.persistentID) { item in
                        Button {
                            musicPlayer.playLocalItem(item, from: musicPlayer.localSongs)
                        } label: {
                            LocalMediaItemRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Library")
        .task {
            musicPlayer.requestLocalLibraryAuthorizationIfNeeded()
        }
        .refreshable {
            musicPlayer.reloadLocalLibrary()
        }
    }
}

#Preview {
    let musicKitService = MusicKitServiceFactory.create()
    AppRootNavigation {
        LibraryScreen()
    }
    .environment(musicKitService)
    .environment(MusicPlayerService())
    .environment(NavPath())
}
