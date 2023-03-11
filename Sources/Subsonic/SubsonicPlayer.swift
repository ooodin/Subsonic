//
// SubsonicPlayer.swift
// Part of Subsonic, a simple library for playing sounds in SwiftUI
//
// This file contains the SubsonicPlayer class, which handles
// loading and playing a single sound that publishes whether it
// is currently playing or not.
//
// Copyright (c) 2021 Paul Hudson.
// See LICENSE for license information.
//

import AVFoundation

/// Responsible for loading and playing a single sound attached to a SwiftUI view.
public class SubsonicPlayer: NSObject, ObservableObject {
    /// A Boolean representing whether this sound is currently playing.
    @Published public var isPlaying = false

    /// The internal audio player being managed by this object.
    private var audioPlayer: AVPlayer?

    /// How loud to play this sound relative to other sounds in your app,
    /// specified in the range 0 (no volume) to 1 (maximum volume).
    public var volume: Double {
        didSet {
            audioPlayer?.volume = Float(volume)
        }
    }

    /// Whether playback should restart from the beginning each time, or
    /// continue from the last playback point.
    public var playMode: SubsonicController.PlayMode

    /// Creates a new instance by looking for a particular sound filename in a bundle of your choosing.of `.reset`.
    /// - Parameters:
    ///   - sound: The name of the sound file you want to load.
    ///   - volume: How loud to play this sound relative to other sounds in your app,
    ///     specified in the range 0 (no volume) to 1 (maximum volume).
    ///   - playMode: Whether playback should restart from the beginning each time, or
    ///     continue from the last playback point.
    public init(sound: String, volume: Double = 1.0, playMode: SubsonicController.PlayMode = .reset) {
        audioPlayer = SubsonicController.shared.prepare(sound: sound)

        self.volume = volume
        self.playMode = playMode

        super.init()
        
        if let item = audioPlayer?.currentItem {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(itemDidFinishPlaying(_:)),
                name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                object: item
            )
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Plays the current sound. If `playMode` is set to `.reset` this will play from the beginning,
    /// otherwise it will play from where the sound last left off.
    public func play() {
        isPlaying = true

        if playMode == .reset {
            audioPlayer?.seek(to: .zero)
        }
        audioPlayer?.play()
    }

    /// Stops the audio from playing.
    public func stop() {
        isPlaying = false
        
        audioPlayer?.pause()
    }
}

// MARK: - AVPlayer notifications observing

private extension SubsonicPlayer {
    @objc func itemDidFinishPlaying(_ notification: Notification) {
        isPlaying = false
    }
}
