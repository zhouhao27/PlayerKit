//
//  PlayingInfo.swift
//  PlayerKit
//
//  Created by Hiroki Kumamoto on 2017/03/09.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation

public struct PlayingInfo {
    public var duration:    TimeInterval
    public var elapsedTime: TimeInterval
    public init(duration: TimeInterval, elapsedTime: TimeInterval) {
        self.duration    = duration
        self.elapsedTime = elapsedTime
    }
}
