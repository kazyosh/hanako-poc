//
//  ConversationStatusBar.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/09.
//

import SwiftUI

struct ConversationStatusBar: View {
    let state: ConversationState
    
    var body: some View {
        HStack(spacing: 8) {
            statusIcon
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(statusColor)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(statusColor.opacity(0.1))
        .animation(.easeInOut(duration: 0.2), value: state)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "moon.zzz")
        case .listening:
            Image(systemName: "mic.fill")
                .symbolEffect(.pulse, isActive: true)
        case .thinking:
            Image(systemName: "ellipsis.circle")
                .symbolEffect(.pulse, isActive: true)
        case .speaking:
            Image(systemName: "speaker.wave.2.fill")
                .symbolEffect(.pulse, isActive: true)
        }
    }
    
    private var statusText: String {
        switch state {
        case .idle:
            return "待機中"
        case .listening:
            return "聞いています..."
        case .thinking:
            return "考えています..."
        case .speaking:
            return "話しています..."
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .thinking:
            return .orange
        case .speaking:
            return .green
        }
    }
}
