//
//  ChatMessage.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/01.
//

import Foundation

struct TurnCost: Codable, Equatable {
    var sttAudioSeconds: Double?
    var llmInputTokens: Int?
    var llmOutputTokens: Int?
    var llmProviderName: String?  // "ChatGPT" / "Claude" など表示用の文字列で保持
    var ttsCharacterCount: Int?
    
    var sttCostJPY: Double
    var llmCostJPY: Double
    var ttsCostJPY: Double
    var totalCostJPY: Double
}

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }
    
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let isVisible: Bool
    var cost: TurnCost?  // アシスタント応答にのみ付与される

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        isVisible: Bool = true,
        cost: TurnCost? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isVisible = isVisible
        self.cost = cost
    }
}
