//
//  MusicPlayerServiceProtocols.swift
//  MuzakKitApp
//
//  Created by Damien L Thompson on 2025-04-07.
//

import Foundation
import MusicKit
import MediaPlayer
import UIKit

protocol MusicPlayerServiceProtocol {

    var playbackState: MusicKit.MusicPlayer.PlaybackStatus { get }
    var currentItem: MusicKit.MusicPlayer.Queue.Entry? { get }
    var artwork: Artwork? { get }
    var localArtworkImage: UIImage? { get }
    var displayTitle: String { get }
    var displaySubtitle: String { get }
    var currentDuration: TimeInterval? { get }
    var hasQueue: Bool { get }
    var currentPlayBackTime: TimeInterval? { get }
    var preferredPlaybackRate: Float { get }
    var actualPlaybackRate: Float { get }
    var rememberPlaybackSpeed: Bool { get }
    var playbackPitchMode: PlaybackPitchMode { get }
    var playbackRateMessage: String? { get }
    var localLibraryAuthorizationStatus: MPMediaLibraryAuthorizationStatus { get }
    var localAlbums: [MPMediaItemCollection] { get }
    var localArtists: [MPMediaItemCollection] { get }
    var localGenres: [MPMediaItemCollection] { get }
    var localPlaylists: [MPMediaPlaylist] { get }
    var localSongs: [MPMediaItem] { get }
    var recentlyAddedSongs: [MPMediaItem] { get }

    func startPlayBackTimer()
    func stopPlayBackTimer()
    func seek(to time: TimeInterval)
    func requestLocalLibraryAuthorizationIfNeeded()
    func reloadLocalLibrary()
    func localCollections(for section: LocalLibrarySection) -> [MPMediaItemCollection]
    func playLocalItem(_ item: MPMediaItem, from items: [MPMediaItem])
    func setPreferredPlaybackRate(_ rate: Float)
    func setRememberPlaybackSpeed(_ rememberPlaybackSpeed: Bool)
    func resetPlaybackRate()
    func setPlaybackPitchMode(_ mode: PlaybackPitchMode)
    func applyPreferredPlaybackRate()
    func handleItemSelected<T>(for item: T, from items: MusicItemCollection<T>) where T: PlayableMusicItem
    func handlePlayback(for items: PlayableMusicItem)
    func shufflePlayback(for items: PlayableMusicItem)
    func togglePlayBack()
    func playNext(_ track: Track?, _ loadedTracks: MusicItemCollection<Track>?)
    func playLast()
    func skipToPrevious()
    func skipToNext()
    func beginPlaying()
}
