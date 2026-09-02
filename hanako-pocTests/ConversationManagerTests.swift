//
//  ConversationManagerTests.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/02.
//

import XCTest
@testable import hanako_poc

@MainActor
final class ConversationManagerTests: XCTestCase {
    let mockSpeaker = MockGreetingSpeaker()
    let mockProvider = MockLLMProvider()

    func test_respond_whenLLMFails_appendsFallbackMessageAndSpeaksIt() async {
        // Arrange
        mockProvider.behavior = .failure(URLError(.notConnectedToInternet))
        
        let manager = ConversationManager(
            llmProvider: mockProvider,
            speechRecognizer: MockSpeechRecognizer(),
            speaker: mockSpeaker
        )
        
        // Act
        await manager.start(prompt: "テスト用の声かけ")
        
        // Assert
        let fallbackMessage = manager.messages.last
        XCTAssertEqual(fallbackMessage?.role, .assistant)
        XCTAssertEqual(fallbackMessage?.content, "ごめんなさい、うまく聞き取れませんでした")
    }
    
    func test_respond_whenLLMSucceeds_doesNotAppendFallbackMessage() async {
        // Arrange
        let mockProvider = MockLLMProvider()
        mockProvider.behavior = .success("元気にしていますか")
        
        let manager = ConversationManager(
            llmProvider: mockProvider,
            speechRecognizer: MockSpeechRecognizer(),
            speaker: mockSpeaker
        )
        
        // Act
        await manager.start(prompt: "テスト用の声かけ")
        
        // Assert
        let lastMessage = manager.messages.last
        XCTAssertEqual(lastMessage?.content, "元気にしていますか")
        XCTAssertNotEqual(lastMessage?.content, "ごめんなさい、うまく聞き取れませんでした")
    }
}
