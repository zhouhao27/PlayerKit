//
//  SpotifyPlayer.swift
//  PlayerKit
//
//  Created by Hiroki Kumamoto on 2017/03/09.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation

open class SpotifyPlayer: NSObject, ConcreteQueuePlayer {
    public typealias ObserverType = QueuePlayerObserver
    public typealias EventType    = QueuePlayerEvent
    fileprivate var _observers: [ObserverType] = []
    public var tracks:       TrackList
    public var trackIndex:   Int = -1
    public var itemIndex:    Int = -1
    open  var  observers: [ObserverType] {
        get { return _observers }
        set { _observers = newValue }
    }
    open var state:       PlayerState { return .init }
    open var playingInfo: PlayingInfo? { return nil }
    open var playerType:  PlayerType { return .spotify }
    open func pause() {}
    open func play() {}
    open func clearPlayer() {}
    open func preparePlayer() {}
    open func seekToTime(_ time: TimeInterval) {}

    public override init() {
        tracks = TrackList(id: "",  tracks: [])
    }
}
