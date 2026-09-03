import Foundation
import AppKit
import CoreAudio

@MainActor
public final class MusicPlaybackWatcher: ObservableObject {
    public static let shared = MusicPlaybackWatcher()

    public var onPlaybackStateChanged: ((Bool) -> Void)?

    public var customMonitoredApps: [CustomMonitoredApp] = [] {
        didSet {
            checkAllPlaybackSourcesNow()
        }
    }

    private(set) var isMonitoredAppPlaying: Bool = false {
        didSet {
            if oldValue != isMonitoredAppPlaying {
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
        return isMonitoredAppPlaying
    }

    // MediaRemote dynamic function bindings
    private typealias MRRegisterForNowPlayingNotificationsFn = @convention(c) (DispatchQueue) -> Void
    private typealias MRGetNowPlayingApplicationIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias MRGetNowPlayingClientFn = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void

    private var getIsPlaying: MRGetNowPlayingApplicationIsPlayingFn?
    private var getInfo: MRGetNowPlayingInfoFn?
    private var getClient: MRGetNowPlayingClientFn?

    private var isMusicAppPlaying: Bool = false
    private var isMediaRemotePlaying: Bool = false
    private var isProcessAudioRunning: Bool = false

    private var pollTimer: Timer?
    private var isQueryingAppleScript = false

    private init() {
        setupMediaRemote()
        registerDistributedNotifications()
        startPeriodicCheck()
        checkAllPlaybackSourcesNow()
    }

    public func updateCustomApps(_ apps: [CustomMonitoredApp]) {
        self.customMonitoredApps = apps
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

    public func isAppMonitored(bundleID: String?, name: String?) -> Bool {
        let bID = (bundleID ?? "").lowercased()
        let appName = (name ?? "").lowercased()

        // 1. Check user custom additions
        for custom in customMonitoredApps {
            let cID = custom.bundleIdentifier.lowercased()
            let cName = custom.name.lowercased()
            if (!cID.isEmpty && (bID == cID || bID.contains(cID))) ||
               (!cName.isEmpty && (appName == cName || appName.contains(cName))) {
                return true
            }
        }

        // 2. Check default monitored bundle identifiers
        for def in AppSettings.defaultMonitoredAppIdentifiers {
            let d = def.lowercased()
            if bID == d || bID.contains(d) {
                return true
            }
        }

        // 3. Check popular media & browser keywords
        let keywords = [
            "music", "spotify", "safari", "chrome", "arc", "brave", "firefox", "edge",
            "opera", "vlc", "iina", "quicktime", "podcast", "tidal", "amazon music",
            "youtube music", "logic pro", "garageband", "ableton", "fl studio", "reaper",
            "audirvana", "swinsian", "bandcamp", "deezer", "qobuz", "soundcloud"
        ]
        for kw in keywords {
            if bID.contains(kw) || appName.contains(kw) {
                return true
            }
        }

        return false
    }

    public func checkAllPlaybackSourcesNow() {
        checkProcessAudioOutputNow()
        checkMediaRemotePlaybackNow()
        checkRunningStateNow()
        updateCombinedState()
    }

    private func updateCombinedState() {
        let shouldPlay = isProcessAudioRunning || isMediaRemotePlaying || isMusicAppPlaying
        self.isMonitoredAppPlaying = shouldPlay
    }

    // MARK: - CoreAudio Per-Process Audio Output Inspection

    public func checkProcessAudioOutputNow() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard status == noErr, size > 0 else {
            self.isProcessAudioRunning = false
            return
        }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var processIDs = [AudioObjectID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &processIDs)

        var foundRunningMonitoredApp = false

        for pidObj in processIDs {
            var isRunningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunning,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var isRunning: UInt32 = 0
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(pidObj, &isRunningAddress, 0, nil, &runSize, &isRunning) == noErr, isRunning != 0 else {
                continue
            }

            var pidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyPID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var pid: pid_t = 0
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            guard AudioObjectGetPropertyData(pidObj, &pidAddress, 0, nil, &pidSize, &pid) == noErr else {
                continue
            }

            let app = NSRunningApplication(processIdentifier: pid)
            let bID = app?.bundleIdentifier
            let name = app?.localizedName

            if isAppMonitored(bundleID: bID, name: name) {
                foundRunningMonitoredApp = true
                break
            }
        }

        self.isProcessAudioRunning = foundRunningMonitoredApp
        updateCombinedState()
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

        if let clientSym = dlsym(handle, "MRMediaRemoteGetNowPlayingClient") {
            getClient = unsafeBitCast(clientSym, to: MRGetNowPlayingClientFn.self)
        }

        let center = NotificationCenter.default
        center.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkMediaRemotePlaybackNow()
            }
        }

        center.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkMediaRemotePlaybackNow()
            }
        }
    }

    public func checkMediaRemotePlaybackNow() {
        guard let getIsPlaying else { return }

        getIsPlaying(DispatchQueue.main) { [weak self] isPlaying in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !isPlaying {
                    self.isMediaRemotePlaying = false
                    self.updateCombinedState()
                    return
                }

                // Verify playbackRate and client app
                if let getInfo = self.getInfo {
                    getInfo(DispatchQueue.main) { [weak self] dict in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            let rate: Double
                            if let d = dict as? [String: Any],
                               let r = (d["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue {
                                rate = r
                            } else {
                                rate = isPlaying ? 1.0 : 0.0
                            }

                            if rate <= 0 {
                                self.isMediaRemotePlaying = false
                                self.updateCombinedState()
                                return
                            }

                            // Check active Now Playing client app
                            if let getClient = self.getClient {
                                getClient(DispatchQueue.main) { [weak self] client in
                                    Task { @MainActor [weak self] in
                                        guard let self else { return }
                                        var clientMatched = true
                                        if let c = client as? NSObject {
                                            let repID = c.value(forKey: "representedBundleID") as? String
                                            let bID = c.value(forKey: "bundleIdentifier") as? String
                                            let parentID = c.value(forKey: "parentApplicationBundleIdentifier") as? String
                                            let dispName = c.value(forKey: "displayName") as? String
                                            clientMatched = self.isAppMonitored(bundleID: repID ?? parentID ?? bID, name: dispName)
                                        }
                                        self.isMediaRemotePlaying = clientMatched
                                        self.updateCombinedState()
                                    }
                                }
                            } else {
                                self.isMediaRemotePlaying = true
                                self.updateCombinedState()
                            }
                        }
                    }
                } else {
                    self.isMediaRemotePlaying = isPlaying
                    self.updateCombinedState()
                }
            }
        }
    }

    // MARK: - Distributed Notifications (Apple Music & Spotify)

    private func registerDistributedNotifications() {
        let center = DistributedNotificationCenter.default()

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
            checkAllPlaybackSourcesNow()
        } else {
            checkRunningStateNow()
        }
    }

    private func startPeriodicCheck() {
        pollTimer?.invalidate()
        // Responsive check every 1.5 seconds so pausing stops headphones immediately
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAllPlaybackSourcesNow()
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
            updateCombinedState()
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
                self.updateCombinedState()
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
