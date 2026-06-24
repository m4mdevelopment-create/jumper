import AVFoundation
import Foundation

enum GameplaySoundCue: Hashable {
    case jump
    case boost
    case shield
    case collect
    case fail
}

@MainActor
final class GameplaySoundManager {
    static let shared = GameplaySoundManager()

    private var players: [GameplaySoundCue: AVAudioPlayer] = [:]

    private init() { }

    func register(cue: GameplaySoundCue, fileURL: URL) {
        guard let player = try? AVAudioPlayer(contentsOf: fileURL) else { return }

        player.prepareToPlay()
        players[cue] = player
    }

    func playJump(isEnabled: Bool) {
        play(.jump, isEnabled: isEnabled)
    }

    func playBoost(isEnabled: Bool) {
        play(.boost, isEnabled: isEnabled)
    }

    func playShield(isEnabled: Bool) {
        play(.shield, isEnabled: isEnabled)
    }

    func playCollect(isEnabled: Bool) {
        play(.collect, isEnabled: isEnabled)
    }

    func playFail(isEnabled: Bool) {
        play(.fail, isEnabled: isEnabled)
    }

    private func play(_ cue: GameplaySoundCue, isEnabled: Bool) {
        guard isEnabled, let player = players[cue] else { return }

        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }
}
