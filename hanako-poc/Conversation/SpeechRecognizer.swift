import Speech

class SpeechRecognizer: NSObject {
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    var silenceThreshold: Float = -60.0
    private let endOfSpeechSilenceDuration: TimeInterval = 1.5
    private var silenceTimer: Timer?
    private var hasDetectedSpeech = false
    
    private let conversationTimeoutDuration: TimeInterval = 20.0
    private var conversationTimeoutTimer: Timer?
    
    private var onResult: ((String) -> Void)?
    private var onConversationTimeout: (() -> Void)?
    
    // 多重起動防止・タップ状態管理
    private var isListening = false
    private var isTapInstalled = false
    
    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechStatus else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
    
    func startListening(
        onResult: @escaping (String) -> Void,
        onConversationTimeout: @escaping () -> Void = {}
    ) throws {
        // 既にリスニング中なら、まず完全にクリーンアップしてから開始し直す
        if isListening {
            stopListening()
        }
        isListening = true
        
        recognitionTask?.cancel()
        recognitionTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        hasDetectedSpeech = false
        
        self.onResult = onResult
        self.onConversationTimeout = onConversationTimeout
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            isListening = false
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        // 念のため、タップが残っていれば必ず外してからインストールする
        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error as NSError? {
                print("recognitionTask error: domain=\(error.domain), code=\(error.code), description=\(error.localizedDescription)")
            }
            
            if let result = result {
                print(result.bestTranscription.formattedString)
                if result.isFinal {
                    let text = result.bestTranscription.formattedString
                    self?.stopListening()
                    if !text.isEmpty {
                        self?.onResult?(text)
                    }
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            self?.processSilenceDetection(buffer: buffer)
        }
        isTapInstalled = true
        
        audioEngine.prepare()
        try audioEngine.start()
        
        startConversationTimeoutTimer()
    }
    
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
                self.hasDetectedSpeech = true
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
                self.resetConversationTimeoutTimer()
            } else if self.hasDetectedSpeech && self.silenceTimer == nil {
                let timer = Timer(timeInterval: self.endOfSpeechSilenceDuration, repeats: false) { [weak self] _ in
                    print("発話終了(無音)を検出")
                    self?.recognitionRequest?.endAudio()
                }
                RunLoop.main.add(timer, forMode: .common)
                self.silenceTimer = timer
            }
        }
    }
    
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
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        recognitionRequest?.endAudio()
    }
    
    deinit {
        silenceTimer?.invalidate()
        conversationTimeoutTimer?.invalidate()
    }
}
