//
//  Hanako.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/20.
//

import Foundation
import AVFoundation
import UserNotifications

struct AppConfig {
    static let ttsAPIKey = ""
    static let claudeAPIKey = ""
    static let openAIAPIKey = ""
}

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
    var llmProvider = llmClaudeProvider
    static let shared = Hanako()
    let promptBase = """
    ・絵文字は使わない
    ・Markdown記法(#、*、_、-など)は一切使わない
    ・装飾のない、話し言葉としてそのまま読み上げられるプレーンテキストのみを出力する
    ・挨拶の言葉のみを出力し、説明や前置きは不要
    """
    private var audioPlayer: AVAudioPlayer?
    private var manager = ConversationManager(llmProvider: llmClaudeProvider)

    private init() {}
    
    func useClaudeAPI() {
        manager.switchProvider(to: llmClaudeProvider)
    }
    func useOpenAIAPI() {
        manager.switchProvider(to: llmOpenAIProvider)
    }

    func startGreeting(timeOfDay: TimeOfDay) async {
        let settings = Settings()
        var prompt = settings.morningPrompt
        switch timeOfDay {
        case .morning:
            prompt = settings.morningPrompt
        case .afternoon:
            prompt = settings.afternoonPrompt
        case .evening:
            prompt = settings.eveningPrompt
        }
        do {
            // 1. 朝の挨拶を開始(LLMが最初に話しかける)
            await manager.start(prompt: "\(promptBase)\n\(prompt)")
            // 2. ユーザーが返答したら、それを聞き取って会話を継続
            try await manager.listenAndRespond()
        }
        catch {
            print("エラー: \(error)")
        }

    }

//    func generateGreeting(timeOfDay: TimeOfDay) async throws -> String {
//        let prompt: String
//        let settings = Settings()
//        switch timeOfDay {
//        case .morning:
//            prompt = settings.morningPrompt
//        case .afternoon:
//            prompt = settings.afternoonPrompt
//        case .evening:
//            prompt = settings.eveningPrompt
//        }
//        
//        // LLM APIを呼び出して声掛け台詞を取得
//        let greeting = try await callLLM(prompt: "\(promptBase)\n\(prompt)")
//        return greeting
//    }



//    func callLLM(prompt: String) async throws -> String {
//        return try await llmProvider.generate(prompt: prompt)
//    }

    func scheduleGreeting(time: Date, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "声掛け"
        content.sound = .default
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
