//
//  HistoryView.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/01.
//

import SwiftUI

struct HistoryView: View {
    @State private var recordsByDate: [(date: Date, records: [ConversationRecord])] = []
    private let historyStore = ConversationHistoryStore.shared
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    var body: some View {
        List {
            ForEach(recordsByDate, id: \.date) { entry in
                Section {
                    ForEach(entry.records) { record in
                        NavigationLink {
                            HistoryDetailView(record: record)
                        } label: {
                            HStack {
                                Image(systemName: record.trigger.iconName)
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.trigger.displayLabel)
                                        .font(.subheadline)
                                    
                                    if let firstAssistantMessage = record.messages.first(where: { $0.role == .assistant }) {
                                        Text(firstAssistantMessage.content)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                let cost = record.messages.compactMap { $0.cost?.totalCostJPY }.reduce(0, +)
                                if cost > 0 {
                                    Text(String(format: "¥%.1f", cost))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        deleteRecords(at: offsets, in: entry.date, records: entry.records)
                    }
                } header: {
                    Text(dateFormatter.string(from: entry.date))
                }
            }
        }
        .navigationTitle("会話履歴")
        .onAppear {
            loadRecords()
        }
    }
    
    private func loadRecords() {
        let allRecords = historyStore.loadAllRecords()
        let calendar = Calendar.current
        
        // 日付でグループ化し、各グループ内はトリガーの表示順(朝→昼→夕→ユーザー発話→...)で並べる
        let grouped = Dictionary(grouping: allRecords) { record in
            calendar.startOfDay(for: record.date)
        }
        
        let sortOrder: [ConversationTrigger] = [.morning, .afternoon, .evening, .userInitiated, .timeout, .noResponse]
        
        recordsByDate = grouped
            .map { (date: $0.key, records: $0.value.sorted { lhs, rhs in
                let lhsIndex = sortOrder.firstIndex(of: lhs.trigger) ?? sortOrder.count
                let rhsIndex = sortOrder.firstIndex(of: rhs.trigger) ?? sortOrder.count
                return lhsIndex < rhsIndex
            }) }
            .sorted { $0.date > $1.date }
    }
    
    private func deleteRecords(at offsets: IndexSet, in date: Date, records: [ConversationRecord]) {
        for index in offsets {
            historyStore.delete(for: date, trigger: records[index].trigger)
        }
        loadRecords()
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
                        HStack(spacing: 4) {
                            Text(message.role == .user ? "あなた" : "はなこ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // .noResponseのメッセージのみ、個別にバッジを出す
                            if message.trigger == .noResponse, message.role == .assistant {
                                TriggerBadge(trigger: .noResponse)
                            }
                        }
                        
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
                    Text("このやり取りの合計コスト")
                    Spacer()
                    Text(String(format: "¥%.2f", totalCostJPY))
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle(record.trigger.displayLabel)
    }
}

private struct TriggerBadge: View {
    let trigger: ConversationTrigger
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: trigger.iconName)
            Text(trigger.displayLabel)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.red.opacity(0.15))
        .foregroundColor(.red)
        .clipShape(Capsule())
    }
}

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
