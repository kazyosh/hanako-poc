//
//  LLMProvider.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/24.
//

import Foundation

enum LLMError: Error {
    case invalidResponse
    case apiError(String)
}

protocol LLMProvider {
    func generate(messages: [ChatMessage], turnLog: ConversationTurnLog?) async throws -> String
}

