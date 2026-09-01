//
//  HistoryView.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/01.
//

import SwiftUI

struct HistoryView: View {
    @State private var records: [ConversationRecord] = []
    private let historyStore = ConversationHistoryStore.shared
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    var body: some View {
        List {
            ForEach(records) { record in
                NavigationLink {
                    HistoryDetailView(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatter.string(from: record.date))
                            .font(.headline)
                        if let firstAssistantMessage = record.messages.first(where: { $0.role == .assistant }) {
                            Text(firstAssistantMessage.content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .onDelete(perform: deleteRecords)
        }
        .navigationTitle("会話履歴")
        .onAppear {
            records = historyStore.loadAllRecords()
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            historyStore.delete(for: records[index].date)
        }
        records = historyStore.loadAllRecords()
    }
}

struct HistoryDetailView: View {
    let record: ConversationRecord
    
    var body: some View {
        List(record.messages.filter(\.isVisible)) { message in
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "あなた" : "はなこ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(message.content)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        }
        .navigationTitle("会話の詳細")
    }
}
