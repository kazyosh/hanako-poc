//
//  GoogleSpeechRecognizer.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/26.
//

import AVFoundation

class GoogleSpeechRecognizer: NSObject, SpeechRecognizing {
    private let audioEngine = AVAudioEngine()
    private let apiKey: String
    
    private var audioBuffer = Data()
    private var audioConverter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!
    
    var silenceThreshold: Float = -60.0
    var endOfSpeechSilenceDuration: TimeInterval = 1.5
    private var silenceTimer: Timer?
    private var hasDetectedSpeech = false
    
    var conversationTimeoutDuration: TimeInterval = 20.0
    private var conversationTimeoutTimer: Timer?
    
    private let maxRecordingDuration: TimeInterval = 45.0
    private var maxRecordingTimer: Timer?
    
    private var onResult: ((String, ConversationTurnLog) -> Void)?
    private var onConversationTimeout: (() -> Void)?
    
    // 発話区間の計測用(1発話ごとに生成)
    private var currentTurnLog: ConversationTurnLog?
    
    private var isListening = false
    private var isTapInstalled = false
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func requestAuthorization() async -> Bool {
        // Google Cloud STTには専用の認証ダイアログはないため、マイク権限のみ確認する
        return await AVAudioApplication.requestRecordPermission()
    }
    
    func startListening(
        onResult: @escaping (String, ConversationTurnLog) -> Void,
        onConversationTimeout: @escaping () -> Void = {}
    ) throws {
        if isListening {
            stopListening()
        }
        isListening = true
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        hasDetectedSpeech = false
        audioBuffer.removeAll()
        currentTurnLog = nil
        
        self.onResult = onResult
        self.onConversationTimeout = onConversationTimeout
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        audioConverter = AVAudioConverter(from: recordingFormat, to: targetFormat)
        
        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.appendConvertedAudio(buffer: buffer)
            self?.processSilenceDetection(buffer: buffer)
        }
        isTapInstalled = true
        
        audioEngine.prepare()
        try audioEngine.start()
        
        startConversationTimeoutTimer()
        startMaxRecordingTimer()
    }

    // MARK: - 音声フォーマット変換とバッファ蓄積
    
    private func appendConvertedAudio(buffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter else { return }
        
        let outputCapacity = AVAudioFrameCount(targetFormat.sampleRate * 2.0)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else { return }
        
        var hasProvidedData = false
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if hasProvidedData {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasProvidedData = true
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("音声変換エラー: \(error)")
            return
        }
        
        guard let channelData = outputBuffer.int16ChannelData else { return }
        let frameLength = Int(outputBuffer.frameLength)
        let data = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Int16>.size)
        audioBuffer.append(data)
    }
    
    // MARK: - 発話区切りの無音検出
    
    private func processSilenceDetection(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(max(rms, 0.0000001))
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if db > self.silenceThreshold {
                if !self.hasDetectedSpeech {
                    // 発話を検知した最初の瞬間 = このターンのログを開始
                    let log = ConversationTurnLog()
                    self.currentTurnLog = log
                    log.start(.stt)
                }
                self.hasDetectedSpeech = true
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
                self.resetConversationTimeoutTimer()
            } else if self.hasDetectedSpeech && self.silenceTimer == nil {
                let timer = Timer(timeInterval: self.endOfSpeechSilenceDuration, repeats: false) { [weak self] _ in
                    print("発話終了(無音)を検出。Google Cloud STTに送信します")
                    self?.finishListeningAndTranscribe()
                }
                RunLoop.main.add(timer, forMode: .common)
                self.silenceTimer = timer
            }
        }
    }
    
    // MARK: - 最大録音時間の強制打ち切り
    
    private func startMaxRecordingTimer() {
        maxRecordingTimer?.invalidate()
        let timer = Timer(timeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
            print("最大録音時間に達したため強制的に認識処理を行います")
            self?.finishListeningAndTranscribe()
        }
        RunLoop.main.add(timer, forMode: .common)
        maxRecordingTimer = timer
    }

    private func finishListeningAndTranscribe() {
        let capturedAudio = audioBuffer
        let log = currentTurnLog
        stopListening()
        
        guard !capturedAudio.isEmpty, let log = log else { return }
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let text = try await self.transcribe(audioData: capturedAudio)
                log.end(.stt)
                if !text.isEmpty {
                    self.onResult?(text, log)
                }
            } catch {
                log.end(.stt)
                print("Google Cloud STTエラー: \(error)")
            }
        }
    }
    
    // MARK: - Google Cloud Speech-to-Text REST API呼び出し
    
    private func transcribe(audioData: Data) async throws -> String {
        let url = URL(string: "https://speech.googleapis.com/v1/speech:recognize?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "config": [
                "encoding": "LINEAR16",
                "sampleRateHertz": 16000,
                "languageCode": "ja-JP"
            ],
            "audio": [
                "content": audioData.base64EncodedString()
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // STT区間のうち、実際のHTTP通信部分をRTTとして分けて計測したい場合は
        // currentTurnLog?.start(.networkLLM) のような専用フェーズを別途追加してください
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "GoogleSpeechRecognizer", code: -1, userInfo: [NSLocalizedDescriptionKey: "STT APIエラー: \(bodyString)"])
        }
        
        let decoded = try JSONDecoder().decode(STTResponse.self, from: data)
        return decoded.results?.first?.alternatives.first?.transcript ?? ""
    }
    
    private struct STTResponse: Decodable {
        struct Result: Decodable {
            struct Alternative: Decodable {
                let transcript: String
            }
            let alternatives: [Alternative]
        }
        let results: [Result]?
    }
    
    // MARK: - 会話全体の無音(タイムアウト)検出
    
    private func startConversationTimeoutTimer() {
        conversationTimeoutTimer?.invalidate()
        let timer = Timer(timeInterval: conversationTimeoutDuration, repeats: false) { [weak self] _ in
            print("長時間の無音を検出したため会話を終了します")
            self?.stopListening()
            self?.onConversationTimeout?()
        }
        RunLoop.main.add(timer, forMode: .common)
        conversationTimeoutTimer = timer
    }
    
    private func resetConversationTimeoutTimer() {
        startConversationTimeoutTimer()
    }
    
    func stopListening() {
        guard isListening else { return }
        isListening = false
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        conversationTimeoutTimer?.invalidate()
        conversationTimeoutTimer = nil
        maxRecordingTimer?.invalidate()
        maxRecordingTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
    }
    
    deinit {
        silenceTimer?.invalidate()
        conversationTimeoutTimer?.invalidate()
        maxRecordingTimer?.invalidate()
    }
}
