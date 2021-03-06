//  QueuePlayer.swift
//  PlayerKit
//
//  Created by Hiroki Kumamoto on 3/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import AVFoundation
import MediaPlayer
#if os(iOS)
import YouTubeiOSPlayerHelper
#endif

open class QueuePlayerObserver: NSObject, Observer {
    public typealias Event = QueuePlayerEvent
    open func listen(_ event: Event) {
    }
}

public func ==(lhs: QueuePlayerObserver, rhs: QueuePlayerObserver) -> Bool {
    return lhs.isEqual(rhs)
}

public enum QueuePlayerEvent {
    case timeUpdated
    case didPlayToEndTime
    case statusChanged
    case trackSelected(Track, Int, Playlist)
    case trackUnselected(Track, Int, Playlist)
    case previousPlaylistRequested
    case nextPlaylistRequested;
    case errorOccured
    case playlistChanged
    case nextTrackAdded
}

public enum PlayerState {
    case `init`
    case load
    case loadToPlay
    case play
    case pause
    public var isPlaying: Bool {
        return self == PlayerState.loadToPlay || self == PlayerState.play
    }
}

public struct Index {
    public init(track: Int, playlist: Int) {
        self.track    = track
        self.playlist = playlist
    }
    public var track:    Int
    public var playlist: Int
}

open class QueuePlayer: ServicePlayerObserver, Observable {
    public typealias ObserverType = QueuePlayerObserver
    public typealias EventType    = QueuePlayerEvent
    fileprivate var playHandler:                   Any?
    fileprivate var pauseHandler:                  Any?
    fileprivate var previousTrackHandler:          Any?
    fileprivate var nextTrackHandler:              Any?
    fileprivate var changePlaybackPositionHandler: Any?
    fileprivate var _observers: [ObserverType] = []
    open        var  observers: [ObserverType] {
        get { return _observers }
        set { _observers = newValue }
    }
    open fileprivate(set) var playlistQueue: PlaylistQueue {
        didSet {
            oldValue.player      = nil
            playlistQueue.player = self
        }
    }
    fileprivate var queuePlayers: [Player]

    fileprivate var normalPlayer: NormalPlayer? {
        for player in queuePlayers {
            if let player = player as? NormalPlayer {
                return player
            }
        }
        return nil
    }
    #if os(iOS)
    fileprivate var appleMusicPlayer: AppleMusicPlayer? {
        for player in queuePlayers {
            if let player = player as? AppleMusicPlayer {
                return player
            }
        }
        return nil
    }
    #else
    fileprivate var appleMusicPlayer: Player? {
        return nil
    }
    #endif

    fileprivate var spotifyPlayer: SpotifyPlayer? {
        for player in queuePlayers {
            if let player = player as? SpotifyPlayer {
                return player
            }
        }
        return nil
    }

    fileprivate var youtubePlayer: YouTubePlayer? {
        for player in queuePlayers {
            if let player = player as? YouTubePlayer {
                return player
            }
        }
        return nil
    }
    public fileprivate(set) var index: Index?

    public var state: PlayerState {
        if let type = currentTrack?.playerType {
            switch type {
            case .normal:     return normalPlayer?.state     ?? .init
            case .appleMusic: return appleMusicPlayer?.state ?? .init
            case .spotify:    return spotifyPlayer?.state    ?? .init
            case .youtube:    return youtubePlayer?.state    ?? .init
            }
        }
        return .init
    }

    open var avPlayer: AVPlayer?  {
        if let type = currentTrack?.playerType {
            switch type {
            case .normal:
                return normalPlayer?.queuePlayer
            default:
                return nil
            }
        }
        return nil
    }
    #if os(iOS)
    open var playerView: YTPlayerView? {
        if let type = currentTrack?.playerType {
            switch type {
            case .youtube:
                return youtubePlayer?.playerView
            default:
                return nil
            }
        }
        return nil
    }
    #endif
    open var playingInfo: PlayingInfo? {
        if let type = currentTrack?.playerType {
            switch type {
            case .normal:     return normalPlayer?.playingInfo
            case .appleMusic: return appleMusicPlayer?.playingInfo
            case .spotify:    return spotifyPlayer?.playingInfo
            case .youtube:    return youtubePlayer?.playingInfo
            }
        }
        return nil
    }
    open var playOnlyBackground: Bool {
        #if os(iOS)
            return UIApplication.shared.applicationState == UIApplicationState.background
        #else
            return false
        #endif
    }
    open func playlist(at i: Index, in queue: PlaylistQueue) -> Playlist? {
        return queue.playlists.get(i.playlist)
    }
    open func track(at i: Index, in queue: PlaylistQueue) -> Track? {
        return playlist(at: i, in: queue)?.tracks.get(i.track)
    }
    open var currentPlaylist: Playlist?  {
        return index.flatMap { playlist(at: $0, in: playlistQueue) }
    }
    open var currentTrack: Track? {
        return index.flatMap { track(at: $0, in: playlistQueue) }
    }

    open func isSelected(at i: Index, in queue: PlaylistQueue) -> Bool {
        return self.playlistQueue == queue && isSelected(at: i)
    }

    open func isSelected(at i: Index) -> Bool {
        guard let targetPlaylist  = playlistQueue.playlists.get(i.playlist) else { return false }
        guard let currentPlaylist = currentPlaylist                         else { return false }
        guard let trackIndex      = index?.track                            else { return false }
        return  currentPlaylist.id == targetPlaylist.id && trackIndex == i.track
    }


    public override init() {
        playlistQueue = PlaylistQueue(playlists: [])
        queuePlayers  = []
        super.init()
        addPlayer(NormalPlayer())
        #if os(iOS)
        addPlayer(AppleMusicPlayer())
        #endif
    }

    deinit {
    }

    @available(OSX 10.12.2, *)
    open func observeCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        playHandler = commandCenter.playCommand.addTarget {_ in
            self.play()
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        pauseHandler = commandCenter.pauseCommand.addTarget {_ in
            self.pause()
            return .success
        }
        commandCenter.previousTrackCommand.isEnabled = true
        previousTrackHandler = commandCenter.previousTrackCommand.addTarget {_ in
            self.previous()
            return .success
        }
        commandCenter.nextTrackCommand.isEnabled = true
        nextTrackHandler = commandCenter.nextTrackCommand.addTarget {_ in
            self.next()
            return .success
        }
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.isEnabled = true
            changePlaybackPositionHandler = commandCenter.changePlaybackPositionCommand.addTarget {
                if let event = $0 as? MPChangePlaybackPositionCommandEvent {
                    self.seekToTime(event.positionTime)
                    return .success
                }
                return .commandFailed
            }
        }
    }

    @available(OSX 10.12.2, *)
    open func stopObservingCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(playHandler)
        commandCenter.pauseCommand.removeTarget(pauseHandler)
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.removeTarget(changePlaybackPositionHandler)
        }
    }

    open func addPlayer(_ player: Player) {
        if var player = player as? NormalPlayer {
            player.addObserver(self)
        }
        #if os(iOS)
        if var player = player as? AppleMusicPlayer {
            player.addObserver(self)
        }
        #endif
        if var player = player as? SpotifyPlayer {
            player.addObserver(self)
        }
        if var player = player as? YouTubePlayer {
            player.addObserver(self)
        }
        queuePlayers.append(player)
    }

    open override func listen(_ event: ServicePlayerObserver.Event) {
        switch event {
        case .timeUpdated:
            notify(.timeUpdated)
        case .didPlayToEndTime:
            notify(.didPlayToEndTime)
            if let _ = nextTrackIndexPath() {
                next()
                play()
            } else {
                notify(.nextPlaylistRequested)
            }
        case .statusChanged:
            notify(.statusChanged)
        case .errorOccured:
            notify(.errorOccured)
        }
    }

    fileprivate func prepare(for targetIndex: Index) {
        if let t = currentTrack, let i = index?.track, let p = currentPlaylist {
            notify(.trackUnselected(t, i, p))
        }
        self.index = targetIndex
        guard let track = currentTrack else { return }
        normalPlayer?.clearPlayer()
        appleMusicPlayer?.clearPlayer()
        spotifyPlayer?.clearPlayer()
        youtubePlayer?.clearPlayer()
        switch track.playerType {
        case .normal:     normalPlayer?.prepare(for: track)
        case .appleMusic: appleMusicPlayer?.prepare(for: track)
        case .spotify:    spotifyPlayer?.prepare(for: track)
        case .youtube:    youtubePlayer?.prepare(for: track)
        }
        if let t = currentTrack, let i = index?.track, let p = currentPlaylist  {
            notify(.trackSelected(t, i, p))
        }
    }

    open func select(at i: Index, in queue: PlaylistQueue) {
        guard let track = track(at: i, in: queue) else { return }
        if isSelected(at: i, in: queue) {
            return
        }
        if !track.isValid {
            return
        }
        self.playlistQueue = queue
        prepare(for: i)
    }

    open func toggle(at i: Index, in queue: PlaylistQueue) {
        guard let _ = track(at: i, in: queue) else { return }
        if isSelected(at: i, in: queue) {
            toggle()
        } else {
            play(at: i, in: queue)
        }
    }

    open func play(at i: Index, in queue: PlaylistQueue) {
        guard let _ = track(at: i, in: queue) else { return }
        if !isSelected(at: i, in: queue) {
            self.playlistQueue = queue
            prepare(for: i)
        }
        play()
    }

    open func play() {
        guard let playerType = currentTrack?.playerType else { return }
        switch playerType {
        case .normal:     normalPlayer?.play()
        case .appleMusic: appleMusicPlayer?.play()
        case .spotify:    spotifyPlayer?.play()
        case .youtube:    youtubePlayer?.play()
        }
    }

    open func pause() {
        guard let playerType = currentTrack?.playerType else { return }
        switch playerType {
        case .normal:     normalPlayer?.pause()
        case .appleMusic: appleMusicPlayer?.pause()
        case .spotify:    spotifyPlayer?.pause()
        case .youtube:    youtubePlayer?.pause()
        }
    }

    open func toggle() {
        guard let playerType = currentTrack?.playerType else { return }
        switch playerType {
        case .normal:     normalPlayer?.toggle()
        case .appleMusic: appleMusicPlayer?.toggle()
        case .spotify:    spotifyPlayer?.toggle()
        case .youtube:    youtubePlayer?.toggle()
        }
    }

    open var previousTrack: Track? {
        return previousTrackIndexPath().flatMap { track(at: $0, in: playlistQueue) }
    }

    open var nextTrack: Track? {
        return nextTrackIndexPath().flatMap { track(at: $0, in: playlistQueue) }
    }

    fileprivate func previousTrackIndexPath() -> Index? {
        guard var playlistIndex = index?.playlist else { return nil }
        guard var trackIndex    = index?.track    else { return nil }
        guard var playlist      = currentPlaylist else { return nil }
        while (true) {
            trackIndex -= 1
            if trackIndex >= 0 {
                let track = playlist.tracks[trackIndex]
                if track.isValid && (track.canPlayBackground || !playOnlyBackground) {
                    return Index(track: trackIndex, playlist: playlistIndex)
                }
            } else {
                playlistIndex -= 1
                if playlistIndex < 0 {
                    return nil
                } else {
                    playlist   = playlistQueue.playlists[playlistIndex]
                    trackIndex = playlist.tracks.count
                }
            }
        }
    }

    fileprivate func nextTrackIndexPath() -> Index? {
        guard var playlistIndex = index?.playlist else { return nil }
        guard var trackIndex    = index?.track    else { return nil }
        guard var playlist      = currentPlaylist else { return nil }
        while (true) {
            trackIndex += 1
            if trackIndex < playlist.tracks.count {
                let track = playlist.tracks[trackIndex]
                if track.isValid && (track.canPlayBackground || !playOnlyBackground) {
                    return Index(track: trackIndex, playlist: playlistIndex)
                }
            } else {
                playlistIndex += 1
                trackIndex     = -1
                if playlistIndex >= playlistQueue.playlists.count {
                    return nil
                } else {
                    playlist = playlistQueue.playlists[playlistIndex]
                }
            }
        }
    }

    open func previous() {
        guard let _ = currentTrack?.playerType else { return }
        guard let i = previousTrackIndexPath() else { return }
        let isPlaying = state.isPlaying
        prepare(for: i)
        if isPlaying {
            play()
        } else {
            pause()
        }
    }

    open func next() {
        guard let _ = currentTrack?.playerType else { return }
        guard let i = nextTrackIndexPath()     else { return }
        let isPlaying = state.isPlaying
        prepare(for: i)
        if isPlaying {
            play()
        } else {
            pause()
        }
    }

    fileprivate func updateTime(_ time: CMTime) {
        notify(.timeUpdated)
    }

    open func seekToTime(_ time: TimeInterval) {
        guard let playerType = currentTrack?.playerType else { return }
        switch playerType {
        case .normal:     normalPlayer?.seekToTime(time)
        case .appleMusic: appleMusicPlayer?.seekToTime(time)
        case .spotify:    spotifyPlayer?.seekToTime(time)
        case .youtube:    youtubePlayer?.seekToTime(time)
        }
        notify(.timeUpdated)
    }

    open func nextTrackAdded() {
        notify(.nextTrackAdded)
    }
}
