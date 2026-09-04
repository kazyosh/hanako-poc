//
//  HistoryView.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/01.
//

import SwiftUI

private struct CostBadge: View {
    let cost: TurnCost
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "yensign.circle")
                .font(.caption2)
            Text(String(format: "¥%.3f", cost.totalCostJPY))
                .font(.caption2)
            
            if let provider = cost.llmProviderName {
                Text("(\(provider))")
                    .font(.caption2)
            }
        }
        .foregroundColor(.secondary)
        .padding(.top, 2)
    }
}

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
                        
                        let totalCost = record.messages.compactMap { $0.cost?.totalCostJPY }.reduce(0, +)
                        if totalCost > 0 {
                            Text(String(format: "この日のコスト: ¥%.2f", totalCost))
                                .font(.caption2)
                                .foregroundColor(.secondary)
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

    private var totalCostJPY: Double {
        record.messages.compactMap { $0.cost?.totalCostJPY }.reduce(0, +)
    }
    
    var body: some View {
        List {
            Section {
                ForEach(record.messages.filter(\.isVisible)) { message in
                    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                        Text(message.role == .user ? "あなた" : "はなこ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(message.content)
                        
                        if let cost = message.cost {
                            CostBadge(cost: cost)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                }
            }
            
            Section {
                HStack {
                    Text("この日の合計コスト")
                    Spacer()
                    Text(String(format: "¥%.2f", totalCostJPY))
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle("会話の詳細")
    }
}
