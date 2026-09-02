//
//  MockGreetingSpeaker.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/02.
//

import Foundation

final class MockGreetingSpeaker: GreetingSpeaking {
    private(set) var spokenTexts: [String] = []
    
    func speak(text: String) async {
        spokenTexts.append(text)
    }
}
