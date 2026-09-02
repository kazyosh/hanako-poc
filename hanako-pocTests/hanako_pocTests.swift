//
//  hanako_pocTests.swift
//  hanako-pocTests
//
//  Created by 吉田 和裕 on 2026/09/02.
//

import Testing
import XCTest
import Foundation

struct hanako_pocTests {
    
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }
    
    func test_respond_whenLLMFails_speaksFallbackMessage() async {
        let mockProvider = MockLLMProvider()
        mockProvider.behavior = .failure(URLError(.notConnectedToInternet))
        let mockSpeaker = MockGreetingSpeaker()
        
        let manager = await ConversationManager(
            llmProvider: mockProvider,
            speechRecognizer: MockSpeechRecognizer(),
            speaker: mockSpeaker
        )
        
        await manager.start(prompt: "テスト用の声かけ")
        
        XCTAssertEqual(mockSpeaker.spokenTexts.last, "ごめんなさい、うまく聞き取れませんでした")
    }
}
