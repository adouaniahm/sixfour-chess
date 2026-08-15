//
//  AudioService.swift
//  SixFourChess
//
//  Sound synthesis entirely in code via AVAudioEngine.
//  No external audio files - sounds are generated from PCM buffers.
//
//  System behavior respected:
//  - Mute switch (silent mode) -> total silence (.ambient)
//  - Media volume buttons -> sound volume
//  - Mix with other apps (background music) -> preserved
//

import AVFoundation

// MARK: - Protocol

protocol AudioServiceProtocol {
    func configureAudioSession()
    func playMoveSound()
    func playCaptureSound()
    func playCheckSound()
    func playVictorySound()
}

// MARK: - AudioService

final class AudioService: AudioServiceProtocol {
    static let shared = AudioService()

    private let engine      = AVAudioEngine()
    private let playerNode  = AVAudioPlayerNode()
    private let format      : AVAudioFormat
    private var buffers     : [String: AVAudioPCMBuffer] = [:]

    private static let sampleRate: Double = 44_100

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        setupEngine()
        configureAudioSession()
        generateAllBuffers()
        startEngine()
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    private func startEngine() {
        do {
            try engine.start()
            playerNode.play()
            Logger.debug("AVAudioEngine started", subsystem: .audio)
        } catch {
            Logger.error("AVAudioEngine start failed: \(error.localizedDescription)", subsystem: .audio)
        }
    }

    // MARK: - Audio Session

    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // `.ambient`: mute switch and media volume are both respected.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            Logger.debug("Audio session configured (.ambient + mixWithOthers)", subsystem: .audio)
        } catch {
            Logger.error("Audio session error: \(error.localizedDescription)", subsystem: .audio)
        }
    }

    // MARK: - Buffer Generation

    private func generateAllBuffers() {
        // Dry wood click (normal move).
        buffers["move"]    = makeClick(frequency: 1_000, duration: 0.06, decay: 35, amplitude: 0.55)
        // Stronger impact (capture).
        buffers["capture"] = makeClick(frequency: 620,   duration: 0.10, decay: 22, amplitude: 0.65)
        // Double alert beep (check).
        buffers["check"]   = makeDoubleBeep(freq1: 880, freq2: 660)
        // Ascending arpeggio (victory / checkmate).
        buffers["victory"] = makeArpeggio(notes: [261.63, 329.63, 392.00, 523.25], noteDuration: 0.14)
    }

    /// Click sound: sine wave with a fast exponential envelope.
    private func makeClick(frequency: Double,
                           duration: Double,
                           decay: Double,
                           amplitude: Float) -> AVAudioPCMBuffer? {
        let sr          = format.sampleRate
        let frameCount  = AVAudioFrameCount(sr * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t       = Double(i) / sr
            let env     = Float(exp(-t * decay))
            data[i]     = amplitude * env * Float(sin(2 * .pi * frequency * t))
        }
        return buffer
    }

    /// Two short beeps separated by a short pause, used as an alert signal.
    private func makeDoubleBeep(freq1: Double, freq2: Double) -> AVAudioPCMBuffer? {
        let sr              = format.sampleRate
        let beepDuration    = 0.075
        let gap             = 0.04
        let totalDuration   = beepDuration * 2 + gap
        let frameCount      = AVAudioFrameCount(sr * totalDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength  = frameCount
        let data            = buffer.floatChannelData![0]
        let beepFrames      = Int(sr * beepDuration)
        let gapFrames       = Int(sr * gap)

        for i in 0..<Int(frameCount) {
            var sample: Float = 0
            if i < beepFrames {
                let t   = Double(i) / sr
                let env = Float(exp(-t * 28))
                sample  = 0.5 * env * Float(sin(2 * .pi * freq1 * t))
            } else if i >= beepFrames + gapFrames {
                let t   = Double(i - beepFrames - gapFrames) / sr
                let env = Float(exp(-t * 28))
                sample  = 0.5 * env * Float(sin(2 * .pi * freq2 * t))
            }
            data[i] = sample
        }
        return buffer
    }

    /// Ascending arpeggio: a sequence of notes (C-E-G-C).
    private func makeArpeggio(notes: [Double], noteDuration: Double) -> AVAudioPCMBuffer? {
        let sr              = format.sampleRate
        let totalDuration   = noteDuration * Double(notes.count)
        let frameCount      = AVAudioFrameCount(sr * totalDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength  = frameCount
        let data            = buffer.floatChannelData![0]

        for (index, freq) in notes.enumerated() {
            let start   = Int(Double(index) * noteDuration * sr)
            let end     = min(start + Int(noteDuration * sr), Int(frameCount))
            for i in start..<end {
                let t       = Double(i - start) / sr
                let env     = Float(exp(-t * 7))
                data[i]     += 0.42 * env * Float(sin(2 * .pi * freq * t))
            }
        }
        return buffer
    }

    // MARK: - Playback

    private var soundEnabled: Bool {
        UserSettingsStorage.shared.loadSoundEnabled()
    }

    private func play(_ key: String) {
        guard soundEnabled else { return }
        guard let buffer = buffers[key] else { return }
            // `.interrupts` stops the previous sound if it is still playing.
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    func playMoveSound()    { play("move")    }
    func playCaptureSound() { play("capture") }
    func playCheckSound()   { play("check")   }
    func playVictorySound() { play("victory") }
}
