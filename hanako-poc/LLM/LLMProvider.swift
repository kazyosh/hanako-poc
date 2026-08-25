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

struct ChatMessage {
    enum Role: String {
        case user
        case assistant
    }
    let role: Role
    let content: String
}

protocol LLMProvider {
    func generate(messages: [ChatMessage]) async throws -> String
}

