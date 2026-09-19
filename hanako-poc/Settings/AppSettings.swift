//
//  AppSettings.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/27.
//


import Foundation

struct GreetingTime: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var hour: Int
    var minute: Int
    var label: String  // "朝" "昼" "夕方" など、UI表示用
}

struct AppSettings: Codable, Equatable {
    var silenceThreshold: Float = -60.0
    var endOfSpeechSilenceDuration: TimeInterval = 1.5
    var conversationTimeoutDuration: TimeInterval = 20.0
    var isDailyGreetingEnabled: Bool = false
    var morning = Date()
    var morningPrompt = "朝の挨拶を一言、親しみやすく自然な日本語で作って。長さは20文字程度。"
    var afternoon = Date()
    var afternoonPrompt = "昼の挨拶を一言、親しみやすく自然な日本語で作って。長さは20文字程度。"
    var evening = Date()
    var eveningPrompt = "夕方の挨拶を一言、親しみやすく自然な日本語で作って。長さは20文字程度。"
    var greetingTimes: [GreetingTime] = [
        GreetingTime(hour: 7, minute: 0, label: "朝"),
        GreetingTime(hour: 12, minute: 0, label: "昼"),
        GreetingTime(hour: 17, minute: 0, label: "夕")
    ]
    var voiceName: String = VoiceOptionsLoader.defaultVoice.name
    private static let storageKey = "appSettings"
    
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return decoded
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
