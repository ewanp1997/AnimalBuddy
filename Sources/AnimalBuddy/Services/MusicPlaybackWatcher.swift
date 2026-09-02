import Foundation
import AppKit

@MainActor
public final class MusicPlaybackWatcher: ObservableObject {
    public static let shared = MusicPlaybackWatcher()

    public var onPlaybackStateChanged: ((Bool) -> Void)?

    private(set) var isSystemMediaPlaying: Bool = false {
        didSet {
            if oldValue != isSystemMediaPlaying {
                notifyChange()
            }
        }
    }

    private(set) var isMusicAppPlaying: Bool = false {
        didSet {
            if oldValue != isMusicAppPlaying {
                notifyChange()
            }
        }
    }

    private(set) var isPreviewActive: Bool = false {
        didSet {
            if oldValue != isPreviewActive {
                notifyChange()
            }
        }
    }

    public var isEffectivelyPlaying: Bool {
        if isPreviewActive { return true }
        return isSystemMediaPlaying || isMusicAppPlaying
    }

    // MediaRemote dynamic function bindings
    private typealias MRRegisterForNowPlayingNotificationsFn = @convention(c) (DispatchQueue) -> Void
    private typealias MRGetNowPlayingApplicationIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void

    private var getIsPlaying: MRGetNowPlayingApplicationIsPlayingFn?
    private var getInfo: MRGetNowPlayingInfoFn?

    private var pollTimer: Timer?
    private var isQueryingAppleScript = false

    private init() {
        setupMediaRemote()
        registerDistributedNotifications()
        startPeriodicCheck()
        checkSystemMediaPlaybackNow()
        checkRunningStateNow()
    }

    public func setPreview(active: Bool) {
        isPreviewActive = active
    }

    public func togglePreview() {
        isPreviewActive.toggle()
    }

    private func notifyChange() {
        onPlaybackStateChanged?(isEffectivelyPlaying)
    }

    // MARK: - MediaRemote System-Wide Playback Detection

    private func setupMediaRemote() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            return
        }

        if let regSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let registerFn = unsafeBitCast(regSym, to: MRRegisterForNowPlayingNotificationsFn.self)
            registerFn(DispatchQueue.main)
        }

        if let isPlayingSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            getIsPlaying = unsafeBitCast(isPlayingSym, to: MRGetNowPlayingApplicationIsPlayingFn.self)
        }

        if let infoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(infoSym, to: MRGetNowPlayingInfoFn.self)
        }

        // Register for system-wide Now Playing notifications
        let center = NotificationCenter.default
        center.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemMediaPlaybackNow()
            }
        }

        center.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemMediaPlaybackNow()
            }
        }
    }

    public func checkSystemMediaPlaybackNow() {
        guard let getIsPlaying else { return }

        getIsPlaying(DispatchQueue.main) { [weak self] isPlaying in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !isPlaying {
                    self.isSystemMediaPlaying = false
                } else if let getInfo = self.getInfo {
                    // Check playback rate from Now Playing info (rate == 0 means paused)
                    getInfo(DispatchQueue.main) { [weak self] dict in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            if let d = dict as? [String: Any],
                               let rate = (d["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue {
                                self.isSystemMediaPlaying = (rate > 0)
                            } else {
                                self.isSystemMediaPlaying = isPlaying
                            }
                        }
                    }
                } else {
                    self.isSystemMediaPlaying = isPlaying
                }
            }
        }
    }

    // MARK: - Distributed Notifications (Apple Music & Spotify)

    private func registerDistributedNotifications() {
        let center = DistributedNotificationCenter.default()

        // Apple Music notification
        center.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let playerState = notification.userInfo?["Player State"] as? String
            Task { @MainActor [weak self] in
                self?.handlePlayerStateChanged(playerState)
            }
        }

        // Legacy iTunes notification
        center.addObserver(
            forName: NSNotification.Name("com.apple.iTunes.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let playerState = notification.userInfo?["Player State"] as? String
            Task { @MainActor [weak self] in
                self?.handlePlayerStateChanged(playerState)
            }
        }

        // Spotify notification
        center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let playerState = notification.userInfo?["Player State"] as? String
            Task { @MainActor [weak self] in
                self?.handlePlayerStateChanged(playerState)
            }
        }
    }

    private func handlePlayerStateChanged(_ state: String?) {
        if let state {
            let playing = (state.caseInsensitiveCompare("Playing") == .orderedSame)
            self.isMusicAppPlaying = playing
            if !playing {
                // When paused, immediately verify system media state as well
                checkSystemMediaPlaybackNow()
            }
        } else {
            checkRunningStateNow()
        }
    }

    private func startPeriodicCheck() {
        pollTimer?.invalidate()
        // Fast, lightweight polling every 1.5 seconds to promptly catch pause events
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemMediaPlaybackNow()
                self?.checkRunningStateNow()
            }
        }
    }

    public func checkRunningStateNow() {
        guard !isQueryingAppleScript else { return }

        let musicApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        let spotifyApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")

        let isMusicAppRunning = musicApps.contains { !$0.isTerminated }
        let isSpotifyAppRunning = spotifyApps.contains { !$0.isTerminated }

        if !isMusicAppRunning && !isSpotifyAppRunning {
            self.isMusicAppPlaying = false
            return
        }

        isQueryingAppleScript = true
        Task.detached(priority: .utility) { [isMusicAppRunning, isSpotifyAppRunning] in
            var playing = false

            if isMusicAppRunning {
                let script = "tell application \"Music\" to get (player state as string)"
                if let output = Self.runAppleScript(script), output.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("playing") == .orderedSame {
                    playing = true
                }
            }

            if !playing && isSpotifyAppRunning {
                let script = "tell application \"Spotify\" to get (player state as string)"
                if let output = Self.runAppleScript(script), output.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("playing") == .orderedSame {
                    playing = true
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isQueryingAppleScript = false
                self.isMusicAppPlaying = playing
            }
        }
    }

    nonisolated private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let descriptor = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return descriptor.stringValue
    }
}
