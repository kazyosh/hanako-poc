//
//  ConversationManager.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/24.
//

import Foundation
import Combine

@MainActor
class ConversationManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConversationActive = true
    private var llmProvider: LLMProvider
    //    private let speechRecognizer = SpeechRecognizer()
    private var speechRecognizer: SpeechRecognizing
    private let speaker: GreetingSpeaking
    private let historyStore = ConversationHistoryStore.shared

    init(llmProvider: LLMProvider, speechRecognizer: SpeechRecognizing, speaker: GreetingSpeaking) {
        self.llmProvider = llmProvider
        self.speechRecognizer = speechRecognizer
        self.speaker = speaker
        loadTodaysHistory()
    }
    
    func applySettings(_ settings: AppSettings) {
        speechRecognizer.silenceThreshold = settings.silenceThreshold
        speechRecognizer.endOfSpeechSilenceDuration = settings.endOfSpeechSilenceDuration
        speechRecognizer.conversationTimeoutDuration = settings.conversationTimeoutDuration
    }
    
    func switchProvider(to newProvider: LLMProvider) {
        llmProvider = newProvider
    }
    
    // 声掛けを開始する(会話のきっかけ)
    func start(prompt: String) async {
        isConversationActive = true
        messages = [ChatMessage(role: .user, content: prompt, isVisible: false)]
        await respond()
        await beginListeningLoop()
    }
    
    // ユーザーの発話を受け取り、会話を継続する
    func listenAndRespond() async throws {
        let granted = await speechRecognizer.requestAuthorization()
        guard granted else { return }
        
        try speechRecognizer.startListening(
            onResult: { [weak self] transcribedText in
                guard let self else { return }
                Task {
                    self.messages.append(ChatMessage(role: .user, content: transcribedText))
                    await self.respond()
                    await self.beginListeningLoop()
                }
            },
            onConversationTimeout: { [weak self] in
                guard let self else { return }
                Task {
                    await self.endConversation()
                }
            }
        )
    }
    
    // リスニングをループさせるための内部ヘルパー
    private func beginListeningLoop() async {
        guard isConversationActive else { return }
        do {
            try await listenAndRespond()
        } catch {
            print("リスニング開始エラー: \(error)")
        }
    }
    
    // 長時間の無音により会話を終了する
    private func endConversation() async {
        guard isConversationActive else { return }
        isConversationActive = false
        let farewell = "また何かあれば声をかけてくださいね"
        messages.append(ChatMessage(role: .assistant, content: farewell))
        await speaker.speak(text: sanitizeForSpeech(farewell))
    }
    
    func sanitizeForSpeech(_ text: String) -> String {
        var result = text
        
        let patternsToRemove = [
            "\\*\\*",
            "\\*",
            "__",
            "_",
            "#{1,6}\\s*",
            "`{1,3}",
            "~~",
            "^>\\s*",
            "^-\\s*",
            "^\\d+\\.\\s*"
        ]
        
        for pattern in patternsToRemove {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
    
    // LLMに送信し、応答を音声で再生
    private func respond() async {
        do {
            let cleanText = try await llmProvider.generate(messages: messages)
            let sanitized = sanitizeForSpeech(cleanText)
            
            messages.append(ChatMessage(role: .assistant, content: cleanText))
            await speaker.speak(text: sanitized)
        } catch {
            print("応答生成エラー: \(error)")
            await handleResponseError()
        }
        trimHistoryIfNeeded()
        saveHistory()
    }
    
    private func trimHistoryIfNeeded() {
        let maxMessages = 20
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
    }

    private func handleResponseError() async {
        let fallbackMessage = "ごめんなさい、うまく聞き取れませんでした"
        messages.append(ChatMessage(role: .assistant, content: fallbackMessage))
        await speaker.speak(text: fallbackMessage)
    }

    // MARK: - 履歴の読み込み・保存
    
    private func loadTodaysHistory() {
        if let record = historyStore.load(for: Date()) {
            messages = record.messages
        }
    }
    
    private func saveHistory() {
        historyStore.save(messages: messages, for: Date())
    }
}
