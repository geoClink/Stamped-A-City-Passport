import Foundation
import AVFoundation

// Manages ambient audio for the city experience.
// Stadium crowd sounds (baseball / football) are now spatial RealityKit entities
// in CityImmersiveView — the OS handles head-tracked 3D positioning.
// This manager handles the three non-positional ambient layers only.
final class CityAudioManager {

    static let shared = CityAudioManager()

    private var cityPlayer:     AVAudioPlayer?
    private var rainPlayer:     AVAudioPlayer?
    private var cricketsPlayer: AVAudioPlayer?

    private init() {
        cityPlayer     = makePlayer("city_ambience")
        rainPlayer     = makePlayer("rain_loop")
        cricketsPlayer = makePlayer("night_crickets")

        [cityPlayer, rainPlayer, cricketsPlayer].forEach {
            $0?.numberOfLoops = -1
            $0?.volume = 0
            $0?.prepareToPlay()
            $0?.play()
        }
        cityPlayer?.volume = 0.35
    }

    // MARK: - Public API

    /// Call on each day/night cycle tick (cycleTime: 0=midnight, 0.5=noon)
    func updateForTime(cycleTime: Double) {
        let elevation = sin((cycleTime - 0.25) * 2 * .pi)
        let nightVol: Float
        if elevation < -0.3 {
            nightVol = 0.55
        } else if elevation < 0.1 {
            nightVol = Float((-elevation + 0.1) / 0.4) * 0.55
        } else {
            nightVol = 0
        }
        cricketsPlayer?.setVolume(nightVol, fadeDuration: 4.0)
    }

    func setRaining(_ isRaining: Bool) {
        rainPlayer?.setVolume(isRaining ? 0.7 : 0, fadeDuration: 2.0)
    }

    func stopAll() {
        [cityPlayer, rainPlayer, cricketsPlayer].forEach { $0?.stop() }
    }

    func startAll() {
        [cityPlayer, rainPlayer, cricketsPlayer].forEach {
            if $0?.isPlaying == false { $0?.play() }
        }
        cityPlayer?.volume = 0.35
    }

    // MARK: - Private

    private func makePlayer(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            print("[Audio] Missing \(name).m4a in bundle")
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }
}
