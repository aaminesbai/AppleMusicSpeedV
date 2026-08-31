//
//  SideloadMusicPlayerService.swift
//  MuzakKitApp
//
//  Created for free sideload library playback.
//

import Foundation
import MediaPlayer
import Observation

@MainActor
@Observable
final class SideloadMusicPlayerService {

    static let minimumPlaybackRate: Float = 0.5
    static let maximumPlaybackRate: Float = 2.0
    static let defaultPlaybackRate: Float = 1.0

    private static let preferredPlaybackRateKey = "sideloadPreferredPlaybackRate"
    private static let playbackRateTolerance: Float = 0.01

    private let player = MPMusicPlayerController.applicationQueuePlayer
    private let userDefaults: UserDefaults

    var authorizationStatus: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
    var albums: [MPMediaItemCollection] = []
    var playlists: [MPMediaPlaylist] = []
    var songs: [MPMediaItem] = []
    var nowPlayingItem: MPMediaItem?
    var playbackState: MPMusicPlaybackState = .stopped
    var preferredPlaybackRate: Float
    var actualPlaybackRate: Float = Self.defaultPlaybackRate
    var playbackRateMessage: String?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if userDefaults.object(forKey: Self.preferredPlaybackRateKey) == nil {
            self.preferredPlaybackRate = Self.defaultPlaybackRate
        } else {
            self.preferredPlaybackRate = Self.clampPlaybackRate(userDefaults.float(forKey: Self.preferredPlaybackRateKey))
        }

        player.beginGeneratingPlaybackNotifications()
        observePlayerNotifications()

        if authorizationStatus == .authorized {
            reloadLibrary()
        }

        updatePlaybackState()
    }

    func requestAuthorizationIfNeeded() {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized:
            authorizationStatus = .authorized
            reloadLibrary()
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.authorizationStatus = status
                    if status == .authorized {
                        self?.reloadLibrary()
                    }
                }
            }
        case .denied, .restricted:
            authorizationStatus = MPMediaLibrary.authorizationStatus()
        @unknown default:
            authorizationStatus = MPMediaLibrary.authorizationStatus()
        }
    }

    func reloadLibrary() {
        albums = MPMediaQuery.albums().collections ?? []
        playlists = (MPMediaQuery.playlists().collections ?? []).compactMap { $0 as? MPMediaPlaylist }
        songs = MPMediaQuery.songs().items ?? []
    }

    func play(_ item: MPMediaItem, from items: [MPMediaItem]) {
        guard !items.isEmpty else { return }

        player.setQueue(with: MPMediaItemCollection(items: items))
        player.nowPlayingItem = item
        player.prepareToPlay()
        player.play()
        updatePlaybackState()
        applyPreferredPlaybackRate()
    }

    func togglePlayback() {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
            applyPreferredPlaybackRate()
        }

        updatePlaybackState()
    }

    func skipToNext() {
        player.skipToNextItem()
        updatePlaybackState()
        applyPreferredPlaybackRate()
    }

    func skipToPrevious() {
        player.skipToPreviousItem()
        updatePlaybackState()
        applyPreferredPlaybackRate()
    }

    func setPreferredPlaybackRate(_ rate: Float) {
        preferredPlaybackRate = Self.clampPlaybackRate(rate)
        userDefaults.set(preferredPlaybackRate, forKey: Self.preferredPlaybackRateKey)
        applyPreferredPlaybackRate()
    }

    func resetPlaybackRate() {
        setPreferredPlaybackRate(Self.defaultPlaybackRate)
    }

    private func applyPreferredPlaybackRate() {
        let rate = Self.clampPlaybackRate(preferredPlaybackRate)
        preferredPlaybackRate = rate
        player.currentPlaybackRate = rate
        refreshActualPlaybackRate()

        guard playbackState == .playing else {
            playbackRateMessage = nil
            return
        }

        playbackRateMessage = Self.playbackRatesMatch(actualPlaybackRate, rate)
            ? nil
            : "Playback speed may be limited for this item."
    }

    private func observePlayerNotifications() {
        _ = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackState()
                self?.applyPreferredPlaybackRate()
            }
        }

        _ = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackState()
            }
        }
    }

    private func updatePlaybackState() {
        playbackState = player.playbackState
        nowPlayingItem = player.nowPlayingItem
        refreshActualPlaybackRate()
    }

    private func refreshActualPlaybackRate() {
        actualPlaybackRate = player.currentPlaybackRate
    }

    private static func clampPlaybackRate(_ rate: Float) -> Float {
        return min(max(rate, minimumPlaybackRate), maximumPlaybackRate)
    }

    private static func playbackRatesMatch(_ lhs: Float, _ rhs: Float) -> Bool {
        return abs(lhs - rhs) <= playbackRateTolerance
    }
}
