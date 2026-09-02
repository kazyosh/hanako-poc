//
//  MockLLMProvider.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/02.
//

@testable import hanako_poc

final class MockLLMProvider: LLMProvider {
    enum Behavior {
        case success(String)
        case failure(Error)
    }
    
    var behavior: Behavior = .success("こんにちは")
    private(set) var generateCallCount = 0
    
    func generate(messages: [ChatMessage]) async throws -> String {
        generateCallCount += 1
        switch behavior {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}
