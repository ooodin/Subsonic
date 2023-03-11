//
// SubsonicPlayerModifier.swift
// Part of Subsonic, a simple library for playing sounds in SwiftUI
//
// This file contains the SwiftUI view modifier for playing sounds
// declaratively, so that we can make a sound stop or start based
// on some program state.
//
// Copyright (c) 2021 Paul Hudson.
// See LICENSE for license information.
//

import AVFoundation
import SwiftUI

/// Attaches sounds to a SwiftUI view so they can play based on some program state.
public struct SubsonicPlayerModifier: ViewModifier {
    /// Internal class responsible for communicating AVAudioPlayer events back to our SwiftUI modifier.
    private class PlayerDelegate: NSObject {
        /// The function to be called when a sound has finished playing.
        var onFinish: (() -> Void)?
        var onChangeTime: ((CMTime) -> Void)?
        
        private var timeObserverToken: Any?
        
        init(player: AVPlayer) {
            super.init()
            
            timeObserverToken = player.addPeriodicTimeObserver(
                forInterval: CMTimeMake(value: 1, timescale: 2),
                queue: .main) { [weak self] time in
                    self?.onChangeTime?(time)
                }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(itemDidFinishPlaying(_:)),
                name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            timeObserverToken = nil
        }
        
        /// Called by an AVPlayer when it finishes.
        @objc func itemDidFinishPlaying(_ notification: Notification) {
            onFinish?()
        }
    }

    /// The name of the sound file you want to load.
    let sound: String

    /// Tracks whether the sound should currently be playing or not.
    @Binding var isPlaying: Bool

    /// Tracks whether the sound playing time
    @Binding var currentTime: Double
    @Binding var durationTime: Double
    
    /// How loud to play this sound relative to other sounds in your app,
    /// specified in the range 0 (no volume) to 1 (maximum volume).
    let volume: Double

    /// Whether playback should restart from the beginning each time, or
    /// continue from the last playback point.
    var playMode: SubsonicController.PlayMode = .reset

    /// Our internal audio player, marked @State to keep it alive when our
    /// modifier is recreated.
    @State private var audioPlayer: AVPlayer?

    /// The delegate for our internal audio player, marked @State to keep it
    /// alive when our modifier is recreated.
    @State private var audioPlayerDelegate: PlayerDelegate?

    public func body(content: Content) -> some View {
        content
            .onChange(of: isPlaying) { playing in
                if playing {
                    // When `playMode` is set to `.reset` we need to make sure
                    // all play requests start at time 0.
                    if playMode == .reset {
                        audioPlayer?.seek(to: .zero)
                    }
                    audioPlayer?.play()
                } else {
                    audioPlayer?.pause()
                }
            }
            .onAppear(perform: prepareAudio)
            .onChange(of: volume) { _ in updateAudio() }
            .onChange(of: sound) { _ in prepareAudio() }
    }

    /// Called to initialize all our audio, either because we're just setting up or
    /// because we're changing sound/bundle.
    ///
    /// Doing this work here rather than in an initializer stop SwiftUI from recreating the
    /// audio data every time the view is changed, and also delays the work of loading
    /// audio until the responsible view is actually visible.
    private func prepareAudio() {
        // This SwiftUI modifier is a struct, so we can't set ourselves
        // up as the delegate for our AVAudioPlayer. So, instead we
        // have a little shim: we create a dedicated `PlayerDelegate`
        // class instance that acts as the audio delegate, and forwards
        // its `audioPlayerDidFinishPlaying()` on to us as a callback.

        // Load the audio player, but *do not* play – playback should
        // only happen when the isPlaying Boolean becomes true.
        audioPlayer = SubsonicController.shared.prepare(sound: sound)
                
        if let audioPlayer {
            audioPlayerDelegate = PlayerDelegate(player: audioPlayer)
            audioPlayerDelegate?.onFinish = audioFinished
            audioPlayerDelegate?.onChangeTime = audioTimeChanged
        }
        durationTime = audioPlayer?.currentItem?.duration.seconds ?? 0
        
        updateAudio()
    }

    /// Changes the playback parameters for an existing sound.
    private func updateAudio() {
        audioPlayer?.volume = Float(volume)
    }

    /// Called when our internal player has finished playing, and sets the `isPlaying` Boolean back to false.
    func audioFinished() {
        isPlaying = false
    }
    
    func audioTimeChanged(time: CMTime) {
        currentTime = time.seconds
        durationTime = audioPlayer?.currentItem?.duration.seconds ?? 0
    }
}
