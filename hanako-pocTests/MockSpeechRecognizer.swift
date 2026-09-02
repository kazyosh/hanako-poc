//
//  MockSpeechRecognizer.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/02.
//

import Foundation

final class MockSpeechRecognizer: SpeechRecognizing {
    var silenceThreshold: Float = -60
    var endOfSpeechSilenceDuration: TimeInterval = 1.5
    var conversationTimeoutDuration: TimeInterval = 20
    
    func requestAuthorization() async -> Bool { false } // テストでは常に権限なしにしてリスニングを開始させない
    func startListening(onResult: @escaping (String) -> Void, onConversationTimeout: @escaping () -> Void) throws {}
    func stopListening() {}
}
