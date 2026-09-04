//
//  OpenAIProvider.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/24.
//

import Foundation

class OpenAIProvider: LLMProvider {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func generate(messages: [ChatMessage], turnLog: ConversationTurnLog?) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "max_tokens": 100
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        turnLog?.start(.networkLLM)
        let (data, response) = try await URLSession.shared.data(for: request)
        turnLog?.end(.networkLLM)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: bodyString])
        }
        
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        if let usage = decoded.usage {
            turnLog?.recordLLMUsage(
                provider: .openAI,
                inputTokens: usage.prompt_tokens,
                outputTokens: usage.completion_tokens
            )
        }
        
        return decoded.choices.first?.message.content ?? ""
    }
    
    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        struct Usage: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
        let choices: [Choice]
        let usage: Usage?
    }
}
