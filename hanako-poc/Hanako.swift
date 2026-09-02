//
//  Hanako.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/20.
//

import Foundation
import AVFoundation
import UserNotifications
import Combine

enum TimeOfDay {
    case morning
    case afternoon
    case evening
}

enum TTSError: Error {
    case invalidResponse
    case apiError(String)
    case decodingFailed
}

enum LLMProviderAPI {
    case claudeAPI
    case openAIAPI
}

let llmClaudeProvider: LLMProvider = ClaudeProvider(apiKey: AppConfig.claudeAPIKey)
let llmOpenAIProvider: LLMProvider = OpenAIProvider(apiKey: AppConfig.openAIAPIKey)

class Hanako {
    @Published var messages: [ChatMessage] = []
    @Published var isConversationActive = true
    var llmProvider = llmClaudeProvider
    static let shared = Hanako()
    let promptBase = """
    ・絵文字は使わない
    ・Markdown記法(#、*、_、-など)は一切使わない
    ・装飾のない、話し言葉としてそのまま読み上げられるプレーンテキストのみを出力する
    ・挨拶の言葉のみを出力し、説明や前置きは不要
    """
    private var audioPlayer: AVAudioPlayer?
    public var manager = ConversationManager(llmProvider: llmClaudeProvider,
                                             speechRecognizer: GoogleSpeechRecognizer(apiKey: AppConfig.ttsAPIKey),    speaker: GreetingSpeaker())
    public var settings: AppSettings {
        didSet {
            settings.save()
            scheduleDailyGreetingTimer()
        }
    }
    private var dailyGreetingTimer: Timer?
    // どの時刻(label)まで今日発火済みかを記録する
    private var firedGreetingLabelsToday: Set<String> = []
    private var lastCheckedDay: Date?
    
    private init() {
        settings = AppSettings.load()
        scheduleDailyGreetingTimer()
    }
    
    func useClaudeAPI() {
        manager.switchProvider(to: llmClaudeProvider)
    }
    func useOpenAIAPI() {
        manager.switchProvider(to: llmOpenAIProvider)
    }

    func startGreeting(for greetingTime: GreetingTime) async {
        guard !isConversationActive || messages.isEmpty else { return }
        
        isConversationActive = true
        let prompt = greetingPrompt(for: greetingTime.label)
        messages = [ChatMessage(role: .user, content: prompt, isVisible: false)]
        do {
            // 1. 挨拶を開始(LLMが最初に話しかける)
            await manager.start(prompt: "\(promptBase)\n\(prompt)")
            // 2. ユーザーが返答したら、それを聞き取って会話を継続
            try await manager.listenAndRespond()
        }
        catch {
            print("エラー: \(error)")
        }
    }

    private func greetingPrompt(for label: String) -> String {
        switch label {
        case "朝":
            return settings.morningPrompt
        case "昼":
            return settings.afternoonPrompt
        case "夕方":
            return settings.eveningPrompt
        default:
            return settings.afternoonPrompt
        }
    }

    func startGreeting(timeOfDay: TimeOfDay) async {
        switch timeOfDay {
        case .morning:
            await startGreeting(for: settings.greetingTimes[0])
        case .afternoon:
            await startGreeting(for: settings.greetingTimes[1])
        case .evening:
            await startGreeting(for: settings.greetingTimes[2])
        }
    }
    
    private func scheduleDailyGreetingTimer() {
        dailyGreetingTimer?.invalidate()
        dailyGreetingTimer = nil
        
        guard settings.isDailyGreetingEnabled, !settings.greetingTimes.isEmpty else { return }
        
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAndTriggerGreetings()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        dailyGreetingTimer = timer
        
        checkAndTriggerGreetings()
    }
    
    private func checkAndTriggerGreetings() {
        let calendar = Calendar.current
        let now = Date()
        
        // 日付が変わったら発火済み記録をリセットする
        if let lastDay = lastCheckedDay, !calendar.isDate(lastDay, inSameDayAs: now) {
            firedGreetingLabelsToday.removeAll()
        }
        lastCheckedDay = now
        
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        for greetingTime in settings.greetingTimes {
            guard nowComponents.hour == greetingTime.hour,
                  nowComponents.minute == greetingTime.minute else {
                continue
            }
            
            // 同じ時刻区分が今日すでに発火済みならスキップ
            guard !firedGreetingLabelsToday.contains(greetingTime.label) else {
                continue
            }
            
            firedGreetingLabelsToday.insert(greetingTime.label)
            
            Task {
                await startGreeting(for: greetingTime)
            }
            break // 同時刻に複数該当することは通常ないが、念のため1件処理したら抜ける
        }
    }
}
