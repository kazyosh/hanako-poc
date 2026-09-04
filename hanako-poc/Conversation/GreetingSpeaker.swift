//
//  GreetingSpeaker.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/24.
//

import AVFoundation

protocol GreetingSpeaking {
    func speak(text: String, turnLog: ConversationTurnLog?) async
}

class GreetingSpeaker: NSObject, GreetingSpeaking {
    private var audioPlayer: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Error>?
    
    /// テキストを音声合成し、再生が終わるまで待機する
    func speak(text: String, turnLog: ConversationTurnLog?) async {
        turnLog?.start(.tts)
        defer { turnLog?.end(.tts) }
        
        turnLog?.recordTTSUsage(characterCount: text.count)
        
        do {
            try await setupAudioSession()
            
            turnLog?.start(.networkTTS)
            let audioData = try await synthesizeSpeech(text: text)
            turnLog?.end(.networkTTS)
            
            try await play(audioData: audioData)
        } catch {
            print("音声再生エラー: \(error)")
        }
    }
    
    /// 再生用にオーディオセッションを設定する
    private func setupAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
    
    /// 音声データを再生し、再生完了まで待機する
    private func play(audioData: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                self.continuation = continuation
                audioPlayer = try AVAudioPlayer(data: audioData)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
                
                if audioPlayer?.play() != true {
                    self.continuation = nil
                    continuation.resume(throwing: LLMError.invalidResponse)
                }
            } catch {
                self.continuation = nil
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 現在の再生を停止する
    func stop() {
        audioPlayer?.stop()
        continuation?.resume()
        continuation = nil
    }
    
    func synthesizeSpeech(text: String) async throws -> Data {
        let urlString = "https://texttospeech.googleapis.com/v1/text:synthesize?key=\(AppConfig.ttsAPIKey)"
        
        guard let url = URL(string: urlString) else {
            throw TTSError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "input": [
                "text": text
            ],
            "voice": [
                "languageCode": "ja-JP",
                "name": "ja-JP-Neural2-B",
                "ssmlGender": "FEMALE"
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": 1.0,
                "pitch": 0.0
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "unknown error"
            throw TTSError.apiError(errorText)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audioContentBase64 = json["audioContent"] as? String,
              let audioData = Data(base64Encoded: audioContentBase64) else {
            throw TTSError.decodingFailed
        }
        
        return audioData
    }
}

extension GreetingSpeaker: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        continuation?.resume()
        continuation = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        continuation?.resume(throwing: error ?? LLMError.invalidResponse)
        continuation = nil
    }
}

