//
//  VoiceOption.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/11.
//

import Foundation

struct VoiceOption: Identifiable, Codable, Equatable {
    var id: String { name }
    let name: String
    let displayName: String
    let gender: String
}

private struct VoiceOptionsFile: Codable {
    let voices: [VoiceOption]
    let defaultVoiceName: String
}

enum VoiceOptionsLoader {
    // フォールバック用の最小構成(JSON読み込みに失敗した場合のみ使用)
    private static let fallbackVoices: [VoiceOption] = [
        VoiceOption(name: "ja-JP-Neural2-B", displayName: "はなこ(標準)", gender: "FEMALE")
    ]
    private static let fallbackDefaultVoiceName = "ja-JP-Neural2-B"
    
    static let all: [VoiceOption] = loadFile()?.voices ?? fallbackVoices
    
    static let defaultVoice: VoiceOption = {
        let defaultName = loadFile()?.defaultVoiceName ?? fallbackDefaultVoiceName
        return all.first(where: { $0.name == defaultName }) ?? all.first ?? fallbackVoices[0]
    }()
    
    private static func loadFile() -> VoiceOptionsFile? {
        guard let url = Bundle.main.url(forResource: "VoiceOptions", withExtension: "json") else {
            print("VoiceOptions.jsonが見つかりません。フォールバック値を使用します。")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VoiceOptionsFile.self, from: data)
        } catch {
            print("VoiceOptions.jsonの読み込みに失敗しました: \(error)。フォールバック値を使用します。")
            return nil
        }
    }
}
