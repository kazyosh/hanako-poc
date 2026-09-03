import Speech

protocol SpeechRecognizing {
    func requestAuthorization() async -> Bool
    func startListening(
        onResult: @escaping (String, ConversationTurnLog) -> Void,
        onConversationTimeout: @escaping () -> Void
    ) throws
    func stopListening()
    var silenceThreshold: Float { get set }
    var endOfSpeechSilenceDuration: TimeInterval { get set }
    var conversationTimeoutDuration: TimeInterval { get set }
}

class SpeechRecognizer: NSObject, SpeechRecognizing {
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    var silenceThreshold: Float = -60.0
    var endOfSpeechSilenceDuration: TimeInterval = 1.5
    private var silenceTimer: Timer?
    private var hasDetectedSpeech = false
    
    var conversationTimeoutDuration: TimeInterval = 20.0
    private var conversationTimeoutTimer: Timer?
    
    private var onResult: ((String, ConversationTurnLog) -> Void)?
    private var onConversationTimeout: (() -> Void)?
    
    // 発話区間の計測用(1発話ごとに生成)
    private var currentTurnLog: ConversationTurnLog?
    
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
        onResult: @escaping (String, ConversationTurnLog) -> Void,
        onConversationTimeout: @escaping () -> Void = {}
    ) throws {
        if isListening {
            stopListening()
        }
        isListening = true
        
        recognitionTask?.cancel()
        recognitionTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        hasDetectedSpeech = false
        currentTurnLog = nil
        
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
                    let log = self?.currentTurnLog
                    log?.end(.stt)
                    self?.stopListening()
                    if !text.isEmpty, let log = log {
                        self?.onResult?(text, log)
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
