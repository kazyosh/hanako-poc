//
//  ConversationHistoryStore.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/01.
//

import Foundation

struct ConversationRecord: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date // その日を代表する日付(ファイル名のキーにもする)
    var messages: [ChatMessage]
}

final class ConversationHistoryStore {
    static let shared = ConversationHistoryStore()
    
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    private var historyDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent("ConversationHistory", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func fileURL(for date: Date) -> URL {
        let filename = dateFormatter.string(from: date) + ".json"
        return historyDirectory.appendingPathComponent(filename)
    }
    
    // 指定日の会話を保存する(同じ日のファイルがあれば上書き)
    func save(messages: [ChatMessage], for date: Date = Date()) {
        // "その会話が挨拶やシステム的な内容だけ"のような空の保存を避ける
        guard !messages.isEmpty else { return }
        
        let record = ConversationRecord(date: date, messages: messages)
        let url = fileURL(for: date)
        
        do {
            let data = try JSONEncoder().encode(record)
            try data.write(to: url, options: .atomic)
        } catch {
            print("会話履歴の保存に失敗しました: \(error)")
        }
    }
    
    // 指定日の会話を読み込む
    func load(for date: Date) -> ConversationRecord? {
        let url = fileURL(for: date)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ConversationRecord.self, from: data)
    }
    
    // 保存されている全履歴の一覧(日付の新しい順)を返す
    func loadAllRecords() -> [ConversationRecord] {
        guard let files = try? fileManager.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let records = files.compactMap { url -> ConversationRecord? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ConversationRecord.self, from: data)
        }
        
        return records.sorted { $0.date > $1.date }
    }
    
    // 指定日の履歴を削除する
    func delete(for date: Date) {
        let url = fileURL(for: date)
        try? fileManager.removeItem(at: url)
    }
}

