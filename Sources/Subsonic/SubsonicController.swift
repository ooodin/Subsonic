//
// SubsonicController.swift
// Part of Subsonic, a simple library for playing sounds in SwiftUI
//
// This file contains the main SubsonicController class, which handles
// imperatively playing audio from any view, by calling play().
// It also wraps up the code to prepare audio from a bundle, which is
// used both here and in `SubsonicPlayerModifier`.
//
//  Created by Paul Hudson on 13/11/2021.
//

import AVFoundation

/// The main class responsible for loading and playing sounds.
public class SubsonicController: NSObject {
    /// When bound to some SwiftUI state, this controls how an audio player
    /// responds when playing for a second time.
    public enum PlayMode {
        /// Restarting a sound should start from the beginning each time.
        case reset

        /// Restarting a sound should pick up where it left off, or start from the
        /// beginning if it ended previously.
        case `continue`
    }

    /// This class is *not* designed to be instantiated; please use the `shared` singleton.
    override private init() { }

    /// The main access point to this class. It's a singleton because sounds must
    /// be loaded and stored in order to continue playing after calling play().
    public static let shared = SubsonicController()

    /// The collection of AVPlayer instances that are currently playing.
    private var playingSounds = Set<AVPlayer>()

    /// Life cycle
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Loads, prepares, then plays a single sound from your bundle.
    /// - Parameters:
    ///   - soundUrl: The URL of the sound file you want to load.
    ///   - volume: How loud to play this sound relative to other sounds in your app,
    ///   specified in the range 0 (no volume) to 1 (maximum volume).
    ///   - repeatCount: How many times to repeat this sound. Specifying 0 here
    ///   (the default) will play the sound only once.
    public func play(sound: String, volume: Double = 1) {
        DispatchQueue.global().async {
            guard
                let player = self.prepare(sound: sound)
            else {
                return
            }
            player.volume = Float(volume)
            player.play()

            // We need to keep track of all sounds that are currently
            // being managed by us, so we insert them into the
            // `playingSounds` set on the main queue.
            DispatchQueue.main.async {
                self.playingSounds.insert(player)
            }
        }
    }

    /// Prepares a sound for playback, sending back the audio player for you to
    /// use however you want.
    /// - Parameters:
    ///   - sound: The URL of the sound file you want to load.
    /// - Returns: The prepared AVPlayer instance, ready to play.
    @discardableResult///
    public func prepare(sound: String) -> AVPlayer? {
        guard let soundUrl = URL(string: sound) else { return nil }
        
        let asset = AVURLAsset(url: soundUrl)
        let assetKeys = [
            "playable",
            "hasProtectedContent"
        ]
        asset.loadValuesAsynchronously(forKeys: assetKeys)
        
        let item = AVPlayerItem(asset: asset)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidFinishPlaying(_:)),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: item
        )
        return AVPlayer(playerItem: item)
    }

    /// Stops one specific sound file currently being played centrally by Subsonic.
    public func stop(sound: String) {
        for playingSound in playingSounds {
            let asset = playingSound.currentItem?.asset as? AVURLAsset
            
            if asset?.url.lastPathComponent == sound {
                playingSound.pause()
            }
        }
    }

    /// Stops all sounds currently being played centrally by Subsonic.
    public func stopAllManagedSounds() {
        for playingSound in playingSounds {
            playingSound.pause()
        }
    }
}

// MARK: - AVPlayer notifications observing

extension SubsonicController {
    /// Called when one of our sounds has finished, so we can remove it from the
    /// set of active sounds and Swift can release the memory.
    @objc
    func itemDidFinishPlaying(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem else {
            return
        }
        for playingPlayer in playingSounds {
            if playingPlayer.currentItem == item {
                playingSounds.remove(playingPlayer)
            }
        }
    }
}
