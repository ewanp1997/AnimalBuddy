import AppKit

@MainActor public final class SoundEffectPlayer {
    public static let shared = SoundEffectPlayer()

    private init() {}

    public func playFocusSound(for item: FocusSoundItem, enabled: Bool) {
        guard enabled else { return }
        playNamedSound(item.systemSoundName)
    }

    public func playCuteReaction(enabled: Bool) {
        guard enabled else { return }
        playNamedSound("Tink")
    }

    public func playWorkReminder(enabled: Bool) {
        guard enabled else { return }
        playNamedSound("Hero")
    }

    public func playNamedSound(_ name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.stop()
        sound.play()
    }
}
