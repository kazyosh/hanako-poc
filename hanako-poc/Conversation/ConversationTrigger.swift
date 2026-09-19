//
//  ConversationTrigger.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/19.
//

import Foundation

enum ConversationTrigger: String, Codable, Equatable, Hashable {
    case morning        // 朝の声かけ
    case afternoon       // 昼の声かけ
    case evening          // 夕方の声かけ
    case userInitiated    // ユーザーからの発話
    case timeout           // 無音タイムアウトによる会話終了
    case noResponse         // 応答が得られなかった(LLM/STTエラーなど)
    
    var displayLabel: String {
        switch self {
        case .morning: return "朝の声かけ"
        case .afternoon: return "昼の声かけ"
        case .evening: return "夕方の声かけ"
        case .userInitiated: return "会話"
        case .timeout: return "会話終了"
        case .noResponse: return "応答なし"
        }
    }
    
    var iconName: String {
        switch self {
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "sunset"
        case .userInitiated: return "bubble.left.and.bubble.right"
        case .timeout: return "moon.zzz"
        case .noResponse: return "exclamationmark.triangle"
        }
    }
}

extension ConversationTrigger {
    static func from(timeOfDay: TimeOfDay) -> ConversationTrigger {
        switch timeOfDay {
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .evening: return .evening
        }
    }
    static func from(greetingTime: GreetingTime) -> ConversationTrigger {
        switch greetingTime.label {
        case "朝": return .morning
        case "昼": return .afternoon
        case "夕": return .evening
        default:
            return .morning
        }
    }
}
