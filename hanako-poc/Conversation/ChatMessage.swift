//
//  ChatMessage.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/01.
//

import Foundation

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

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), isVisible: Bool = true) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isVisible = isVisible
    }
}
