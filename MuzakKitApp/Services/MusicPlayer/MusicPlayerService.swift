//
//  MusicPlayerService.swift
//  MuzakKitApp
//
//  Created by Damien L Thompson on 2024-12-28.
//

import MusicKit
import MediaPlayer
import AVFoundation
import Observation
import Combine
import SwiftUI
import UIKit

enum PlaybackPitchMode: String, CaseIterable, Identifiable {

    case preservePitch
    case speedAndPitch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preservePitch:
            "Preserve Pitch"
        case .speedAndPitch:
            "Speed + Pitch"
        }
    }

    var description: String {
        switch self {
        case .preservePitch:
            "Keep vocals and instruments closer to their original pitch while changing speed."
        case .speedAndPitch:
            "Use cassette-style playback when the active player supports pitch changes."
        }
    }
}

enum LocalLibrarySection: String, CaseIterable, Identifiable {

    case playlists
    case artists
    case albums
    case genres
    case songs

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

@Observable
class MusicPlayerService: MusicPlayerServiceProtocol {

    private enum PlaybackSource {
        case musicKit
        case mediaLibrary
        case localFile
    }

    static let minimumPlaybackRate: Float = 0.5
    static let maximumPlaybackRate: Float = 2.0
    static let defaultPlaybackRate: Float = 1.0

    private static let preferredPlaybackRateKey = "preferredPlaybackRate"
    private static let rememberPlaybackSpeedKey = "rememberPlaybackSpeed"
    private static let playbackPitchModeKey = "playbackPitchMode"
    private static let playbackRateTolerance: Float = 0.01

    private var player: ApplicationMusicPlayer
    private var playerState: MusicKit.MusicPlayer.State
    private let mediaPlayer = MPMusicPlayerController.applicationQueuePlayer
    private var localFilePlayer: AVPlayer?
    private var localFileQueue: [MPMediaItem] = []
    private var localFileIndex: Int = 0
    private var localFileEndObserver: NSObjectProtocol?
    private var playbackStatePublisher: AnyCancellable?
    private var queueChangePublisher: AnyCancellable?
    private let userDefaults: UserDefaults
    private var rejectedPlaybackRate: Float?
    private var playbackSource: PlaybackSource = .musicKit

    var playbackState: MusicKit.MusicPlayer.PlaybackStatus = .stopped
    var currentItem: MusicKit.MusicPlayer.Queue.Entry?
    var artwork: Artwork?
    var localArtworkImage: UIImage?
    var displayTitle: String = "Song Title"
    var displaySubtitle: String = "Album Name"
    var currentDuration: TimeInterval?
    var hasQueue: Bool = false
    var currentPlayBackTime: TimeInterval? = 0.0
    var preferredPlaybackRate: Float
    var actualPlaybackRate: Float = 1.0
    var rememberPlaybackSpeed: Bool
    var playbackPitchMode: PlaybackPitchMode
    var playbackRateMessage: String?
    var localLibraryAuthorizationStatus: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
    var localAlbums: [MPMediaItemCollection] = []
    var localArtists: [MPMediaItemCollection] = []
    var localGenres: [MPMediaItemCollection] = []
    var localPlaylists: [MPMediaPlaylist] = []
    var localSongs: [MPMediaItem] = []
    var recentlyAddedSongs: [MPMediaItem] = []

    private var timer: Timer?

    private var isPlaying: Bool {
        return playbackState == .playing
    }

    init(userDefaults: UserDefaults = .standard) {

        self.userDefaults = userDefaults

        let shouldRememberPlaybackSpeed = userDefaults.object(forKey: Self.rememberPlaybackSpeedKey) as? Bool ?? true
        self.rememberPlaybackSpeed = shouldRememberPlaybackSpeed
        self.preferredPlaybackRate = Self.loadPreferredPlaybackRate(
            from: userDefaults,
            shouldRememberPlaybackSpeed: shouldRememberPlaybackSpeed
        )
        self.playbackPitchMode = Self.loadPlaybackPitchMode(from: userDefaults)

        self.player = ApplicationMusicPlayer.shared
        self.playerState = ApplicationMusicPlayer.shared.state

        refreshActualPlaybackRate()
        setupPlayerStateListener()
        setupQueueChangeListener()
        setupMediaPlayerListeners()
        requestLocalLibraryAuthorizationIfNeeded()
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

    private static func loadPlaybackPitchMode(from userDefaults: UserDefaults) -> PlaybackPitchMode {

        guard let value = userDefaults.string(forKey: playbackPitchModeKey),
              let mode = PlaybackPitchMode(rawValue: value) else {
            return .preservePitch
        }

        return mode
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
            guard self.playbackSource == .musicKit else { return }
            updatePlaybackState()
            updateHasQueue()
            refreshActualPlaybackRate()
            reapplyPreferredPlaybackRateIfNeeded()
        }
    }

    private func handleQueueChanged() {

        Task { @MainActor in
            guard self.playbackSource == .musicKit else { return }
            rejectedPlaybackRate = nil
            updateCurrentEntry()
            updateCurrentArtwork()
            updateDisplayMetadata()
            updateHasQueue()
            reapplyPreferredPlaybackRateIfNeeded()
        }
    }

    func startPlayBackTimer() {

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in

            guard self?.playbackState == .playing else {
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
            switch playbackSource {
            case .musicKit:
                self.currentPlayBackTime = player.playbackTime
            case .mediaLibrary:
                self.currentPlayBackTime = mediaPlayer.currentPlaybackTime
            case .localFile:
                self.currentPlayBackTime = localFilePlayer?.currentTime().seconds ?? 0
            }
        }
    }

    private func updateCurrentEntry() {

        self.currentItem = player.queue.currentEntry
    }

    private func updateCurrentArtwork() {

        self.artwork = player.queue.currentEntry?.artwork
        self.localArtworkImage = nil
    }

    private func updateDisplayMetadata() {

        if playbackSource == .mediaLibrary,
           let item = mediaPlayer.nowPlayingItem {
            displayTitle = item.title ?? "Song Title"
            displaySubtitle = item.artist ?? item.albumTitle ?? "Album Name"
            currentDuration = item.playbackDuration > 0 ? item.playbackDuration : nil
            localArtworkImage = item.artwork?.image(at: CGSize(width: 500, height: 500))
            artwork = nil
            return
        }

        if playbackSource == .localFile,
           localFileQueue.indices.contains(localFileIndex) {
            let item = localFileQueue[localFileIndex]
            displayTitle = item.title ?? "Song Title"
            displaySubtitle = item.artist ?? item.albumTitle ?? "Album Name"
            currentDuration = item.playbackDuration > 0 ? item.playbackDuration : nil
            localArtworkImage = item.artwork?.image(at: CGSize(width: 500, height: 500))
            artwork = nil
            currentItem = nil
            return
        }

        displayTitle = currentItem?.title ?? "Song Title"
        displaySubtitle = currentItem?.subtitle ?? "Album Name"
        currentDuration = musicKitDuration(for: currentItem)
    }

    private func updatePlaybackState() {

        self.playbackState = playerState.playbackStatus
    }

    private func updateHasQueue() {

        withAnimation(.spring) {
            switch playbackSource {
            case .musicKit:
                self.hasQueue = !self.player.queue.entries.isEmpty
            case .mediaLibrary, .localFile:
                self.hasQueue = self.mediaPlayer.nowPlayingItem != nil
                    || self.localFilePlayer != nil
            }
        }
    }

    private func musicKitDuration(for entry: MusicKit.MusicPlayer.Queue.Entry?) -> TimeInterval? {

        guard let item = entry?.item else { return nil }

        switch item {
        case .song(let song):
            return song.duration
        case .musicVideo(let musicVideo):
            return musicVideo.duration
        @unknown default:
            return nil
        }
    }
}

// MARK: - Player controls
extension MusicPlayerService {

    func handleItemSelected<T>(for item: T, from items: MusicItemCollection<T>) where T: PlayableMusicItem {

        mediaPlayer.pause()
        playbackSource = .musicKit
        resetPreferredPlaybackRateForNewListeningSessionIfNeeded()
        player.queue = .init(for: items, startingAt: item)
        beginPlaying()
    }

    func handlePlayback(for items: PlayableMusicItem) {

        mediaPlayer.pause()
        playbackSource = .musicKit
        resetPreferredPlaybackRateForNewListeningSessionIfNeeded()
        player.queue = [items]
        beginPlaying()
    }

    func shufflePlayback(for items: PlayableMusicItem) {

        mediaPlayer.pause()
        playbackSource = .musicKit
        toggleSuffleState()
        resetPreferredPlaybackRateForNewListeningSessionIfNeeded()
        player.queue = [items]
        beginPlaying()
    }

    func togglePlayBack() {

        if isPlaying {
            switch playbackSource {
            case .musicKit:
                player.pause()
            case .mediaLibrary:
                mediaPlayer.pause()
                updateMediaPlaybackState()
            case .localFile:
                localFilePlayer?.pause()
                updateLocalFilePlaybackState()
            }
        } else {
            switch playbackSource {
            case .musicKit:
                beginPlaying()
            case .mediaLibrary:
                mediaPlayer.play()
                updateMediaPlaybackState()
                applyPreferredPlaybackRate()
            case .localFile:
                localFilePlayer?.playImmediately(atRate: preferredPlaybackRate)
                updateLocalFilePlaybackState()
                applyPreferredPlaybackRate()
            }
        }
    }

    func playNext(_ track: Track? = nil, _ loadedTracks: MusicItemCollection<Track>? = nil) {

        if let track,
           let loadedTracks,
           let index = loadedTracks.firstIndex(where: { $0.id == track.id }) {

            if index < loadedTracks.count - 1 {
                let nextIndex = loadedTracks.index(after: index)
                let nextItem = loadedTracks[nextIndex]

                mediaPlayer.pause()
                playbackSource = .musicKit
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
        mediaPlayer.pause()
        playbackSource = .musicKit
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

        guard playbackSource == .musicKit else {
            if playbackSource == .localFile {
                if localFileIndex > 0 {
                    playLocalFile(at: localFileIndex - 1)
                } else {
                    seek(to: 0)
                }
                return
            }

            mediaPlayer.skipToPreviousItem()
            updateMediaPlaybackState()
            applyPreferredPlaybackRate()
            return
        }

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

        guard playbackSource == .musicKit else {
            if playbackSource == .localFile {
                playLocalFile(at: localFileIndex + 1)
                return
            }

            mediaPlayer.skipToNextItem()
            updateMediaPlaybackState()
            applyPreferredPlaybackRate()
            return
        }

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

        playbackSource = .musicKit
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

// MARK: - Local MediaPlayer Library
extension MusicPlayerService {

    func requestLocalLibraryAuthorizationIfNeeded() {

        switch MPMediaLibrary.authorizationStatus() {
        case .authorized:
            localLibraryAuthorizationStatus = .authorized
            reloadLocalLibrary()
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.localLibraryAuthorizationStatus = status
                    if status == .authorized {
                        self?.reloadLocalLibrary()
                    }
                }
            }
        case .denied, .restricted:
            localLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
        @unknown default:
            localLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
        }
    }

    func reloadLocalLibrary() {

        localSongs = Self.sortedRecentlyAdded(MPMediaQuery.songs().items ?? [])
        recentlyAddedSongs = Array(localSongs.prefix(50))

        localAlbums = Self.sortedCollectionsByRecentlyAdded(MPMediaQuery.albums().collections ?? [])
        localArtists = Self.sortedCollectionsByTitle(MPMediaQuery.artists().collections ?? [])
        localGenres = Self.sortedCollectionsByTitle(MPMediaQuery.genres().collections ?? [])
        localPlaylists = (MPMediaQuery.playlists().collections ?? [])
            .compactMap { $0 as? MPMediaPlaylist }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    func localCollections(for section: LocalLibrarySection) -> [MPMediaItemCollection] {

        switch section {
        case .albums:
            return localAlbums
        case .artists:
            return localArtists
        case .genres:
            return localGenres
        case .playlists:
            return localPlaylists.map { $0 as MPMediaItemCollection }
        case .songs:
            return []
        }
    }

    func playLocalItem(_ item: MPMediaItem, from items: [MPMediaItem]) {

        guard !items.isEmpty else { return }

        if item.assetURL != nil {
            playLocalFile(item, from: items)
            return
        }

        localFilePlayer?.pause()
        player.pause()
        playbackSource = .mediaLibrary
        currentItem = nil
        artwork = nil

        mediaPlayer.setQueue(with: MPMediaItemCollection(items: items))
        mediaPlayer.nowPlayingItem = item
        mediaPlayer.prepareToPlay()
        mediaPlayer.play()

        updateMediaPlaybackState()
        applyPreferredPlaybackRate()
    }

    private func playLocalFile(_ item: MPMediaItem, from items: [MPMediaItem]) {

        guard let index = items.firstIndex(where: { $0.persistentID == item.persistentID }) else { return }

        localFileQueue = items
        localFileIndex = index
        playLocalFile(at: index)
    }

    private func playLocalFile(at index: Int) {

        guard localFileQueue.indices.contains(index) else {
            localFilePlayer?.pause()
            localFilePlayer = nil
            playbackState = .stopped
            updateHasQueue()
            return
        }

        let item = localFileQueue[index]

        guard let url = item.assetURL else {
            playLocalItem(item, from: localFileQueue)
            return
        }

        mediaPlayer.pause()
        player.pause()
        playbackSource = .localFile
        localFileIndex = index
        currentPlayBackTime = 0

        let playerItem = AVPlayerItem(url: url)
        configurePitchAlgorithm(for: playerItem)

        if let localFileEndObserver {
            NotificationCenter.default.removeObserver(localFileEndObserver)
        }

        localFileEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.skipToNext()
            }
        }

        localFilePlayer = AVPlayer(playerItem: playerItem)
        localFilePlayer?.playImmediately(atRate: preferredPlaybackRate)

        updateLocalFilePlaybackState()
        applyPreferredPlaybackRate()
    }

    func seek(to time: TimeInterval) {

        guard time.isFinite else { return }
        let clampedTime = max(0, min(time, currentDuration ?? time))

        switch playbackSource {
        case .musicKit:
            player.playbackTime = clampedTime
        case .mediaLibrary:
            mediaPlayer.currentPlaybackTime = clampedTime
        case .localFile:
            localFilePlayer?.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600))
        }

        currentPlayBackTime = clampedTime
    }

    private func setupMediaPlayerListeners() {

        mediaPlayer.beginGeneratingPlaybackNotifications()

        _ = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: mediaPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.playbackSource == .mediaLibrary else { return }
                self?.updateMediaPlaybackState()
                self?.applyPreferredPlaybackRate()
            }
        }

        _ = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: mediaPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.playbackSource == .mediaLibrary else { return }
                self?.updateMediaPlaybackState()
            }
        }
    }

    private func updateMediaPlaybackState() {

        switch mediaPlayer.playbackState {
        case .playing, .seekingForward, .seekingBackward:
            playbackState = .playing
        case .paused, .interrupted:
            playbackState = .paused
        case .stopped:
            playbackState = .stopped
        @unknown default:
            playbackState = .stopped
        }

        updateDisplayMetadata()
        updateHasQueue()
        refreshActualPlaybackRate()
    }

    private func updateLocalFilePlaybackState() {

        if localFilePlayer?.rate == 0 {
            playbackState = .paused
        } else {
            playbackState = .playing
        }

        updateDisplayMetadata()
        updateHasQueue()
        refreshActualPlaybackRate()
    }

    private func configurePitchAlgorithm(for item: AVPlayerItem?) {

        switch playbackPitchMode {
        case .preservePitch:
            item?.audioTimePitchAlgorithm = .spectral
        case .speedAndPitch:
            item?.audioTimePitchAlgorithm = .varispeed
        }
    }

    private static func sortedRecentlyAdded(_ items: [MPMediaItem]) -> [MPMediaItem] {

        items.sorted {
            ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast)
        }
    }

    private static func sortedCollectionsByRecentlyAdded(_ collections: [MPMediaItemCollection]) -> [MPMediaItemCollection] {

        collections.sorted {
            let lhs = $0.items.map { $0.dateAdded ?? .distantPast }.max() ?? .distantPast
            let rhs = $1.items.map { $0.dateAdded ?? .distantPast }.max() ?? .distantPast
            return lhs > rhs
        }
    }

    private static func sortedCollectionsByTitle(_ collections: [MPMediaItemCollection]) -> [MPMediaItemCollection] {

        collections.sorted {
            let lhs = $0.representativeItem?.artist ?? $0.representativeItem?.albumTitle ?? ""
            let rhs = $1.representativeItem?.artist ?? $1.representativeItem?.albumTitle ?? ""
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
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

    func setPlaybackPitchMode(_ mode: PlaybackPitchMode) {
        playbackPitchMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.playbackPitchModeKey)
        configurePitchAlgorithm(for: localFilePlayer?.currentItem)
        applyPreferredPlaybackRate()
    }

    func applyPreferredPlaybackRate() {

        let rate = Self.clampPlaybackRate(preferredPlaybackRate)
        preferredPlaybackRate = rate

        switch playbackSource {
        case .musicKit:
            playerState.playbackRate = rate
        case .mediaLibrary:
            mediaPlayer.currentPlaybackRate = rate
        case .localFile:
            configurePitchAlgorithm(for: localFilePlayer?.currentItem)

            if playbackState == .playing {
                localFilePlayer?.rate = rate
            }
        }

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

        switch playbackSource {
        case .musicKit:
            actualPlaybackRate = playerState.playbackRate
        case .mediaLibrary:
            actualPlaybackRate = mediaPlayer.currentPlaybackRate
        case .localFile:
            actualPlaybackRate = localFilePlayer?.rate ?? 0
        }
    }

    private func verifyPlaybackRateChange(requestedRate: Float) {

        refreshActualPlaybackRate()

        guard playbackState == .playing else {
            playbackRateMessage = nil
            logPlaybackSpeedDiagnostics(context: "rate requested while not playing")
            return
        }

        if playbackSource == .mediaLibrary,
           playbackPitchMode == .speedAndPitch {
            playbackRateMessage = "Speed + Pitch needs a locally stored, unprotected file."
        } else if Self.playbackRatesMatch(actualPlaybackRate, requestedRate) {
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
        let songTitle = displayTitle == "Song Title" ? currentItem?.title ?? "Unknown" : displayTitle
        let playbackTime = currentPlayBackTime ?? 0
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
