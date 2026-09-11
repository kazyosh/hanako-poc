//
//  VoiceOption.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/09/11.
//

import Foundation

struct VoiceOption: Identifiable, Codable, Equatable {
    var id: String { name }
    let name: String          // Google Cloud TTSのvoice名(APIに渡す値)
    let displayName: String   // UIに表示する名前
    let gender: String        // "FEMALE" / "MALE"
    
    static let all: [VoiceOption] = [
        VoiceOption(name: "ja-JP-Neural2-B", displayName: "はなこ(標準)", gender: "FEMALE"),
        VoiceOption(name: "ja-JP-Neural2-C", displayName: "たろう(男性)", gender: "MALE"),
        VoiceOption(name: "ja-JP-Neural2-D", displayName: "けんじ(男性・落ち着いた声)", gender: "MALE"),
        VoiceOption(name: "ja-JP-Wavenet-A", displayName: "さくら(やわらかい声)", gender: "FEMALE"),
        VoiceOption(name: "ja-JP-Wavenet-B", displayName: "みゆき(はきはきした声)", gender: "FEMALE")
    ]
    
    static let `default` = all[0]
}
