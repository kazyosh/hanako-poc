//
//  ConversationManager.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/24.
//

import Foundation
import Combine

enum ConversationState: Equatable {
    case idle           // 会話していない(待機中)
    case listening       // ユーザーの発話を聞いている
    case thinking         // LLMが応答を生成中
    case speaking         // TTSで応答を再生中
}

@MainActor
class ConversationManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConversationActive = true
    @Published var conversationState: ConversationState = .idle
    private var llmProvider: LLMProvider
    private var speechRecognizer: SpeechRecognizing
    private let speaker: GreetingSpeaking
    private let historyStore = ConversationHistoryStore.shared
    private var voiceName: String = VoiceOptionsLoader.defaultVoice.name

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
        voiceName = settings.voiceName
    }
    
    func switchProvider(to newProvider: LLMProvider) {
        llmProvider = newProvider
    }
    
    // 声掛けを開始する(会話のきっかけ)
    // STTは発生しないが、LLM/TTSのコストは計測する
    func start(prompt: String) async {
        isConversationActive = true
        let turnLog = ConversationTurnLog()
        messages = [ChatMessage(role: .user, content: prompt, isVisible: false)]
        await respond(turnLog: turnLog)
        await beginListeningLoop()
    }
    
    // ConversationManagerに追加
    func previewVoice(_ voiceName: String) async {
        await speaker.speak(text: "こんにちは、この声でお話しします", voiceName: voiceName, turnLog: nil)
    }

    // ユーザーの発話を受け取り、会話を継続する
    func listenAndRespond() async throws {
        let granted = await speechRecognizer.requestAuthorization()
        guard granted else { return }
        
        conversationState = .listening  // リスニング開始
        try speechRecognizer.startListening(
            onResult: { [weak self] transcribedText, turnLog in
                guard let self else { return }
                Task {
                    self.messages.append(ChatMessage(role: .user, content: transcribedText))
                    await self.respond(turnLog: turnLog)
                    await self.beginListeningLoop()
                }
            },
            onNoSpeechDetected: { [weak self] in
                guard let self else { return }
                Task {
                    // 何も聞き取れなかった場合は、リスニングを再開して継続する
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
        guard isConversationActive else {
            conversationState = .idle  // 会話終了時はidleに戻す
            return
        }
        do {
            try await listenAndRespond()
        } catch {
            print("リスニング開始エラー: \(error)")
            conversationState = .idle
        }
    }
    
    // 長時間の無音により会話を終了する
    // STTは発生しないが、TTSのコストは計測する
    private func endConversation() async {
        guard isConversationActive else { return }
        isConversationActive = false
        let farewell = "また何かあれば声をかけてくださいね"
        
        let turnLog = ConversationTurnLog()
        let messageID = UUID()
        messages.append(ChatMessage(id: messageID, role: .assistant, content: farewell))
        
        conversationState = .speaking
        await speaker.speak(text: sanitizeForSpeech(farewell), voiceName: voiceName, turnLog: turnLog)
        
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].cost = turnLog.makeTurnCost()
        }
        saveHistory()
        turnLog.printSummary()
        conversationState = .idle
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
    private func respond(turnLog: ConversationTurnLog?) async {
        conversationState = .thinking
        turnLog?.start(.llm)
        do {
            let cleanText = try await llmProvider.generate(messages: messages, turnLog: turnLog)
            turnLog?.end(.llm)
            
            let sanitized = sanitizeForSpeech(cleanText)
            let messageID = UUID()
            messages.append(ChatMessage(id: messageID, role: .assistant, content: cleanText))
            
            conversationState = .speaking
            await speaker.speak(text: sanitized, voiceName: voiceName, turnLog: turnLog)
            
            if let index = messages.firstIndex(where: { $0.id == messageID }) {
                messages[index].cost = turnLog?.makeTurnCost()
            }
        } catch {
            turnLog?.end(.llm)
            print("応答生成エラー: \(error)")
            await handleResponseError(turnLog: turnLog)
        }
        trimHistoryIfNeeded()
        saveHistory()
        turnLog?.printSummary()
    }
    
    private func trimHistoryIfNeeded() {
        let maxMessages = 20
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
    }

    private func handleResponseError(turnLog: ConversationTurnLog?) async {
        let fallbackMessage = "ごめんなさい、うまく聞き取れませんでした"
        let messageID = UUID()
        messages.append(ChatMessage(id: messageID, role: .assistant, content: fallbackMessage))
        
        conversationState = .speaking
        await speaker.speak(text: fallbackMessage, voiceName: voiceName, turnLog: turnLog)
        
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].cost = turnLog?.makeTurnCost()
        }
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
