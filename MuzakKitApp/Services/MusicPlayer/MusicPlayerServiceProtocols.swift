//
//  MusicPlayerServiceProtocols.swift
//  MuzakKitApp
//
//  Created by Damien L Thompson on 2025-04-07.
//

import Foundation
import MusicKit

protocol MusicPlayerServiceProtocol {

    var playbackState: MusicPlayer.PlaybackStatus { get }
    var currentItem: MusicPlayer.Queue.Entry? { get }
    var artwork: Artwork? { get }
    var hasQueue: Bool { get }
    var currentPlayBackTime: TimeInterval? { get }
    var preferredPlaybackRate: Float { get }
    var actualPlaybackRate: Float { get }
    var rememberPlaybackSpeed: Bool { get }
    var playbackRateMessage: String? { get }

    func startPlayBackTimer()
    func stopPlayBackTimer()
    func setPreferredPlaybackRate(_ rate: Float)
    func setRememberPlaybackSpeed(_ rememberPlaybackSpeed: Bool)
    func resetPlaybackRate()
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
