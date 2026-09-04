//
//  ClaudeProvider.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/24.
//

import Foundation

class ClaudeProvider: LLMProvider {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String = "claude-haiku-4-5") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func generate(messages: [ChatMessage], turnLog: ConversationTurnLog?) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Claudeは system ロールを別フィールドで扱うため、user/assistantのみを抽出する
        let apiMessages = messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map { ["role": $0.role.rawValue, "content": $0.content] }
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 100,
            "messages": apiMessages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        turnLog?.start(.networkLLM)
        let (data, response) = try await URLSession.shared.data(for: request)
        turnLog?.end(.networkLLM)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ClaudeProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: bodyString])
        }
        
        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        
        turnLog?.recordLLMUsage(
            provider: .claude,
            inputTokens: decoded.usage.input_tokens,
            outputTokens: decoded.usage.output_tokens
        )
        
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
    }
    
    private struct MessagesResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
        struct Usage: Decodable {
            let input_tokens: Int
            let output_tokens: Int
        }
        let content: [ContentBlock]
        let usage: Usage
    }
}
