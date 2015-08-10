//
//  MiniPlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import SnapKit
import WebImage

public class MiniPlayerViewController: UIViewController, MiniPlayerViewDelegate {
    class MiniPlayerObserver: PlayerObserver {
        let vc: MiniPlayerViewController
        init(miniPlayerViewController: MiniPlayerViewController) {
            vc = miniPlayerViewController
            super.init()
        }
        override func timeUpdated()      { vc.updateViews() }
        override func didPlayToEndTime() { vc.updateViews() }
        override func statusChanged()    { vc.updateViews() }
    }
    public var mainViewController:               UIViewController?
    var miniPlayerObserver:                      MiniPlayerObserver!
    public var player:                           Player<PlayerObserver>?
    @IBOutlet public weak var mainViewContainer: UIView!
    @IBOutlet public weak var miniPlayerView:    MiniPlayerView!

    public init(player: Player<PlayerObserver>) {
        let bundle = NSBundle(identifier: "io.kumabook.PlayerKit")
        super.init(nibName: "MiniPlayerViewController", bundle: bundle)
        self.player = player
        miniPlayerObserver = MiniPlayerObserver(miniPlayerViewController: self)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        if let vc = mainViewController {
            addChildViewController(vc)
            vc.view.frame = mainViewContainer.bounds
            vc.didMoveToParentViewController(self)
            miniPlayerView.delegate = self
            mainViewContainer.addSubview(vc.view)
            view.bringSubviewToFront(miniPlayerView)
            updateViews()
            player?.addObserver(miniPlayerObserver)
        }
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func updateViews() {
        if let track = player?.currentTrack {
            let playingInfoCenter: AnyClass? = NSClassFromString("MPNowPlayingInfoCenter")
            if let center: AnyClass = playingInfoCenter {
                var info:[String:AnyObject]                           = [:]
                info[MPMediaItemPropertyTitle]                        = track.title
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = info
            }
            miniPlayerView.titleLabel.text = track.title
            if let (current, total) = player?.secondPair {
                miniPlayerView.durationLabel.text = TimeHelper.timeStr(Float(current))
            } else {
                miniPlayerView.durationLabel.text = "00:00"
            }
            let imageManager = SDWebImageManager()
            if let url = track.thumbnailUrl {
                imageManager.downloadImageWithURL(url,
                    options: SDWebImageOptions.HighPriority,
                   progress: {receivedSize, expectedSize in },
                  completed: { (image, error, cacheType, finished, url) -> Void in
                    self.updateMPNowPlaylingInfoCenter(track, image: image)
                })
            } else {
                self.updateMPNowPlaylingInfoCenter(track, image: UIImage(named: "default_thumb")!)
            }
        } else {
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nil
            miniPlayerView.titleLabel.text    = ""
            miniPlayerView.durationLabel.text = "00:00"
        }
        if let state = player?.currentState{
            miniPlayerView.state = state
        }
    }

    func updateMPNowPlaylingInfoCenter(track: Track, image: UIImage) {
        let playingInfoCenter: AnyClass? = NSClassFromString("MPNowPlayingInfoCenter")
        if let center: AnyClass = playingInfoCenter {
            let infoCenter = MPNowPlayingInfoCenter.defaultCenter()
            let albumArt                     = MPMediaItemArtwork(image:image)
            var info:[String:AnyObject]      = [:]
            info[MPMediaItemPropertyTitle]   = track.title
            info[MPMediaItemPropertyArtwork] = albumArt
            infoCenter.nowPlayingInfo        = info
        }
    }

    public func select(trackIndex: Int, playlist: Playlist, playlists: [Playlist]) {
        for i in 0..<playlists.count {
            if playlist.id == playlists[i].id {
                player?.select(trackIndex: trackIndex, playlistIndex: i, playlists: playlists)
            }
        }
    }

    // MARK: - MiniPlayerViewDelegate -
    
    public func miniPlayerViewPlayButtonTouched() {
        player?.toggle()
    }
    
    public func miniPlayerViewPreviousButtonTouched() {
        player?.previous()
    }
    
    public func miniPlayerViewNextButtonTouched() {
        player?.next()
    }
}