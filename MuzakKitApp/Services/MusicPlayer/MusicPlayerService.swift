//
//  MusicPlayerService.swift
//  MuzakKitApp
//
//  Created by Damien L Thompson on 2024-12-28.
//

import MusicKit
import Observation
import Combine
import SwiftUI

@Observable
class MusicPlayerService: MusicPlayerServiceProtocol {

    static let minimumPlaybackRate: Float = 0.5
    static let maximumPlaybackRate: Float = 2.0
    static let defaultPlaybackRate: Float = 1.0

    private static let preferredPlaybackRateKey = "preferredPlaybackRate"
    private static let rememberPlaybackSpeedKey = "rememberPlaybackSpeed"
    private static let playbackRateTolerance: Float = 0.01

    private var player: ApplicationMusicPlayer
    private var playerState: MusicPlayer.State
    private var playbackStatePublisher: AnyCancellable?
    private var queueChangePublisher: AnyCancellable?
    private let userDefaults: UserDefaults
    private var rejectedPlaybackRate: Float?

    var playbackState: MusicPlayer.PlaybackStatus = .stopped
    var currentItem: MusicPlayer.Queue.Entry?
    var artwork: Artwork?
    var hasQueue: Bool = false
    var currentPlayBackTime: TimeInterval? = 0.0
    var preferredPlaybackRate: Float
    var actualPlaybackRate: Float = MusicPlayerService.defaultPlaybackRate
    var rememberPlaybackSpeed: Bool
    var playbackRateMessage: String?

    private var timer: Timer?

    private var isPlaying: Bool {
        return (playerState.playbackStatus == .playing)
    }

    init(userDefaults: UserDefaults = .standard) {

        self.userDefaults = userDefaults

        let shouldRememberPlaybackSpeed = userDefaults.object(forKey: Self.rememberPlaybackSpeedKey) as? Bool ?? true
        self.rememberPlaybackSpeed = shouldRememberPlaybackSpeed
        self.preferredPlaybackRate = Self.loadPreferredPlaybackRate(
            from: userDefaults,
            shouldRememberPlaybackSpeed: shouldRememberPlaybackSpeed
        )

        self.player = ApplicationMusicPlayer.shared
        self.playerState = ApplicationMusicPlayer.shared.state

        refreshActualPlaybackRate()
        setupPlayerStateListener()
        setupQueueChangeListener()
    }

    private static func loadPreferredPlaybackRate(
        from userDefaults: UserDefaults,
        shouldRememberPlaybackSpeed: Bool
    ) -> Float {

        guard shouldRememberPlaybackSpeed,
              userDefaults.object(forKey: preferredPlaybackRateKey) != nil else {
            return defaultPlaybackRate
        }

        return clampPlaybackRate(userDefaults.float(forKey: preferredPlaybackRateKey))
    }

    static func clampPlaybackRate(_ rate: Float) -> Float {
        return min(max(rate, minimumPlaybackRate), maximumPlaybackRate)
    }

    private func setupPlayerStateListener() {

        playbackStatePublisher = player.state.objectWillChange
            .sink { [weak self] _ in
                self?.handlePlayerStateChanged()
            }
    }

    private func setupQueueChangeListener() {

        queueChangePublisher = player.queue.objectWillChange
            .sink { [weak self] _ in
                self?.handleQueueChanged()
            }
    }

    private func handlePlayerStateChanged() {

        Task { @MainActor in
            updatePlaybackState()
            updateHasQueue()
            refreshActualPlaybackRate()
            reapplyPreferredPlaybackRateIfNeeded()
        }
    }

    private func handleQueueChanged() {

        Task { @MainActor in
            rejectedPlaybackRate = nil
            updateCurrentEntry()
            updateCurrentArtwork()
            updateHasQueue()
            reapplyPreferredPlaybackRateIfNeeded()
        }
    }

    func startPlayBackTimer() {

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in

            guard self?.playerState.playbackStatus == .playing else {
                self?.stopPlayBackTimer()
                return
            }

            self?.updatePlaybackTime()
        }
    }

    func stopPlayBackTimer() {

        timer?.invalidate()
    }

    private func updatePlaybackTime() {

        Task { @MainActor in
            self.currentPlayBackTime = player.playbackTime
        }
    }

    private func updateCurrentEntry() {

        self.currentItem = player.queue.currentEntry
    }

    private func updateCurrentArtwork() {

        self.artwork = player.queue.currentEntry?.artwork
    }

    private func updatePlaybackState() {

        self.playbackState = playerState.playbackStatus
    }

    private func updateHasQueue() {

        withAnimation(.spring) {
            self.hasQueue = !self.player.queue.entries.isEmpty
        }
    }
}

// MARK: - Player controls
extension MusicPlayerService {

    func handleItemSelected<T>(for item: T, from items: MusicItemCollection<T>) where T: PlayableMusicItem {

        resetPreferredPlaybackRateForNewListeningSessionIfNeeded()
        player.queue = .init(for: items, startingAt: item)
        beginPlaying()
    }

    func handlePlayback(for items: PlayableMusicItem) {

        resetPreferredPlaybackRateForNewListeningSessionIfNeeded()
        player.queue = [items]
        beginPlaying()
    }

    func shufflePlayback(for items: PlayableMusicItem) {

        toggleSuffleState()
        resetPreferredPlaybackRateForNewListeningSessionIfNeeded()
        player.queue = [items]
        beginPlaying()
    }

    func togglePlayBack() {

        if isPlaying {
            player.pause()
        } else {
            beginPlaying()
        }
    }

    func playNext(_ track: Track? = nil, _ loadedTracks: MusicItemCollection<Track>? = nil) {

        if let track,
           let loadedTracks,
           let index = loadedTracks.firstIndex(where: { $0.id == track.id }) {

            if index < loadedTracks.count - 1 {
                let nextIndex = loadedTracks.index(after: index)
                let nextItem = loadedTracks[nextIndex]

                resetPreferredPlaybackRateForNewListeningSessionIfNeeded()
                player.queue = .init(for: loadedTracks, startingAt: nextItem)
                beginPlaying()
            }
        } else {
            skipToNext()
        }
    }

    func playLast() {

        guard player.isPreparedToPlay, !player.queue.entries.isEmpty else { return }

        let lastTrack = player.queue.entries.last
        let entries = player.queue.entries
        resetPreferredPlaybackRateForNewListeningSessionIfNeeded()
        player.queue = .init(entries, startingAt: lastTrack)

        beginPlaying()
    }

    private func toggleSuffleState() {

        if isPlaying {
            player.pause()
        }

        if playerState.shuffleMode == .off {
            playerState.shuffleMode = .songs
        } else {
            playerState.shuffleMode = .off
        }
    }

    func skipToPrevious() {

        Task {
            do {
                try await player.skipToPreviousEntry()
                await MainActor.run {
                    self.reapplyPreferredPlaybackRateIfNeeded()
                }
            } catch {
                print("Failed to play previous track with error: \(error).")
            }
        }
    }

    func skipToNext() {

        Task {
            do {
                try await player.skipToNextEntry()
                await MainActor.run {
                    self.reapplyPreferredPlaybackRateIfNeeded()
                }
            } catch {
                print("Failed to play next track with error: \(error).")
            }
        }
    }

    func beginPlaying() {

        Task {
            do {
                try await self.player.prepareToPlay()
                try await self.player.play()
                await MainActor.run {
                    self.applyPreferredPlaybackRate()
                }
            } catch {
                print("Failed to begin playback with error: \(error).")
            }
        }
    }
}

// MARK: - Playback Speed
extension MusicPlayerService {

    func setPreferredPlaybackRate(_ rate: Float) {

        preferredPlaybackRate = Self.clampPlaybackRate(rate)
        rejectedPlaybackRate = nil
        persistPreferredPlaybackRateIfNeeded()
        applyPreferredPlaybackRate()
    }

    func setRememberPlaybackSpeed(_ rememberPlaybackSpeed: Bool) {

        self.rememberPlaybackSpeed = rememberPlaybackSpeed
        userDefaults.set(rememberPlaybackSpeed, forKey: Self.rememberPlaybackSpeedKey)

        if rememberPlaybackSpeed {
            persistPreferredPlaybackRateIfNeeded()
        } else {
            userDefaults.removeObject(forKey: Self.preferredPlaybackRateKey)
        }
    }

    func resetPlaybackRate() {
        setPreferredPlaybackRate(Self.defaultPlaybackRate)
    }

    func applyPreferredPlaybackRate() {

        let rate = Self.clampPlaybackRate(preferredPlaybackRate)
        preferredPlaybackRate = rate
        playerState.playbackRate = rate
        verifyPlaybackRateChange(requestedRate: rate)
    }

    private func reapplyPreferredPlaybackRateIfNeeded() {

        refreshActualPlaybackRate()

        guard playbackState == .playing else {
            playbackRateMessage = nil
            return
        }

        guard !Self.playbackRatesMatch(actualPlaybackRate, preferredPlaybackRate) else {
            playbackRateMessage = nil
            rejectedPlaybackRate = nil
            return
        }

        if let rejectedPlaybackRate,
           Self.playbackRatesMatch(rejectedPlaybackRate, preferredPlaybackRate) {
            return
        }

        applyPreferredPlaybackRate()
    }

    private func refreshActualPlaybackRate() {
        actualPlaybackRate = playerState.playbackRate
    }

    private func verifyPlaybackRateChange(requestedRate: Float) {

        refreshActualPlaybackRate()

        guard playbackState == .playing else {
            playbackRateMessage = nil
            logPlaybackSpeedDiagnostics(context: "rate requested while not playing")
            return
        }

        if Self.playbackRatesMatch(actualPlaybackRate, requestedRate) {
            playbackRateMessage = nil
            rejectedPlaybackRate = nil
        } else {
            playbackRateMessage = "Playback speed is not available for this track."
            rejectedPlaybackRate = requestedRate
        }

        logPlaybackSpeedDiagnostics(context: "rate requested")
    }

    private func persistPreferredPlaybackRateIfNeeded() {

        guard rememberPlaybackSpeed else { return }

        userDefaults.set(preferredPlaybackRate, forKey: Self.preferredPlaybackRateKey)
    }

    private func resetPreferredPlaybackRateForNewListeningSessionIfNeeded() {

        guard !rememberPlaybackSpeed else { return }

        preferredPlaybackRate = Self.defaultPlaybackRate
        playbackRateMessage = nil
    }

    private static func playbackRatesMatch(_ lhs: Float, _ rhs: Float) -> Bool {
        return abs(lhs - rhs) <= playbackRateTolerance
    }

    private func logPlaybackSpeedDiagnostics(context: String) {
        #if DEBUG
        let songTitle = currentItem?.title ?? "Unknown"
        let playbackTime = player.playbackTime
        let time = playbackTime.isFinite ? String(format: "%.1f", playbackTime) : "n/a"

        print(
            """
            Playback speed diagnostics (\(context))
            Song: \(songTitle)
            Preferred speed: \(String(format: "%.2f", preferredPlaybackRate))
            MusicKit playbackRate: \(String(format: "%.2f", actualPlaybackRate))
            Status: \(playbackState)
            Playback time: \(time)
            """
        )
        #endif
    }
}
