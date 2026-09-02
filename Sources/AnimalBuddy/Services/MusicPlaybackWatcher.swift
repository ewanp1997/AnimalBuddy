import Foundation
import AppKit
import CoreAudio

@MainActor
public final class MusicPlaybackWatcher: ObservableObject {
    public static let shared = MusicPlaybackWatcher()

    public var onPlaybackStateChanged: ((Bool) -> Void)?

    private(set) var isSystemAudioPlaying: Bool = false {
        didSet {
            if oldValue != isSystemAudioPlaying {
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
        isPreviewActive || isSystemAudioPlaying || isMusicAppPlaying
    }

    private var currentOutputDeviceID: AudioDeviceID = 0
    private var isRunningListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var pollTimer: Timer?
    private var isQuerying = false

    private init() {
        registerSystemAudioListener()
        registerDistributedNotifications()
        startPeriodicCheck()
        checkSystemAudioNow()
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

    // MARK: - System-Wide Audio Output Detection (CoreAudio)

    private func registerSystemAudioListener() {
        updateCurrentOutputDevice()

        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let devBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateCurrentOutputDevice()
                self?.checkSystemAudioNow()
            }
        }
        self.defaultDeviceListenerBlock = devBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main,
            devBlock
        )
    }

    private func updateCurrentOutputDevice() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var newDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &newDeviceID
        )

        guard status == noErr, newDeviceID != 0 else { return }

        if currentOutputDeviceID != 0, let isRunningListenerBlock {
            var oldAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(currentOutputDeviceID, &oldAddress, DispatchQueue.main, isRunningListenerBlock)
        }

        currentOutputDeviceID = newDeviceID

        var isRunningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let runBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.checkSystemAudioNow()
            }
        }
        self.isRunningListenerBlock = runBlock
        AudioObjectAddPropertyListenerBlock(
            newDeviceID,
            &isRunningAddress,
            DispatchQueue.main,
            runBlock
        )
    }

    public func checkSystemAudioNow() {
        guard currentOutputDeviceID != 0 else {
            updateCurrentOutputDevice()
            return
        }

        var isRunningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var isRunningSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            currentOutputDeviceID,
            &isRunningAddress,
            0,
            nil,
            &isRunningSize,
            &isRunning
        )

        if status == noErr {
            self.isSystemAudioPlaying = (isRunning != 0)
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
        } else {
            checkRunningStateNow()
        }
    }

    private func startPeriodicCheck() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemAudioNow()
                self?.checkRunningStateNow()
            }
        }
    }

    public func checkRunningStateNow() {
        guard !isQuerying else { return }

        let musicApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        let spotifyApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")

        let isMusicAppRunning = musicApps.contains { !$0.isTerminated }
        let isSpotifyAppRunning = spotifyApps.contains { !$0.isTerminated }

        if !isMusicAppRunning && !isSpotifyAppRunning {
            self.isMusicAppPlaying = false
            return
        }

        isQuerying = true
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
                self.isQuerying = false
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
