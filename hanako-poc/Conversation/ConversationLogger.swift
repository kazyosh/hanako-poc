import Foundation

enum LLMProviderKind {
    case openAI
    case claude
}

private enum PricingJPY {
    // Google Cloud Speech-to-Text: Standardモデル, 15秒単位課金の目安(1分あたり)
    static let sttPerMinute: Double = 2.4
    
    // Google Cloud TTS: Neural2音声, 100万文字あたりの目安
    static let ttsPerMillionCharacters: Double = 2400.0
    
    // LLM: プロバイダ・モデルごとに単価が異なる(100万トークンあたりの目安)
    // 為替や料金改定で変動するため、必ず最新の公式料金表と照合してください
    static func llmPricing(for provider: LLMProviderKind) -> (input: Double, output: Double) {
        switch provider {
        case .openAI:
            // 例: GPT-4o mini相当の目安
            return (input: 22.5, output: 90.0)
        case .claude:
            // 例: Claude Haiku相当の目安
            return (input: 120.0, output: 600.0)
        }
    }
}

final class ConversationTurnLog {
    enum Phase: String, CaseIterable {
        case stt = "STT"
        case llm = "LLM"
        case tts = "TTS"
        case networkLLM = "LLM通信(RTT)"
        case networkTTS = "TTS通信(RTT)"
    }
    
    // MARK: - 時間計測(既存)
    
    private struct Timing {
        var start: Date?
        var end: Date?
        
        var duration: TimeInterval? {
            guard let start = start, let end = end else { return nil }
            return end.timeIntervalSince(start)
        }
    }
    
    private var timings: [Phase: Timing] = [:]
    private let turnStartedAt = Date()
    private let turnID = String(UUID().uuidString.prefix(8))
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    func start(_ phase: Phase) {
        var timing = timings[phase] ?? Timing()
        timing.start = Date()
        timings[phase] = timing
        print("[\(Self.timeFormatter.string(from: timing.start!))] [\(turnID)] ▶︎ \(phase.rawValue) 開始")
    }
    
    func end(_ phase: Phase) {
        var timing = timings[phase] ?? Timing()
        timing.end = Date()
        timings[phase] = timing
        
        let durationText = timing.duration.map { String(format: "%.3f秒", $0) } ?? "計測不能"
        print("[\(Self.timeFormatter.string(from: timing.end!))] [\(turnID)] ■ \(phase.rawValue) 終了 (所要: \(durationText))")
    }
    
    // MARK: - コスト計測用の使用量記録
    
    struct Usage {
        var sttAudioSeconds: Double?      // STT: 音声の秒数
        var llmInputTokens: Int?          // LLM: 入力トークン数
        var llmOutputTokens: Int?         // LLM: 出力トークン数
        var llmProvider: LLMProviderKind? // LLM種別
        var ttsCharacterCount: Int?       // TTS: 合成文字数
    }
    
    private var usage = Usage()
    
    func recordSTTUsage(audioSeconds: Double) {
        usage.sttAudioSeconds = audioSeconds
    }
    
    func recordLLMUsage(provider: LLMProviderKind, inputTokens: Int, outputTokens: Int) {
        usage.llmProvider = provider
        usage.llmInputTokens = inputTokens
        usage.llmOutputTokens = outputTokens
    }
    
    func recordTTSUsage(characterCount: Int) {
        usage.ttsCharacterCount = characterCount
    }
    
    // MARK: - コスト計算(単価は現時点の目安。実際の料金表と照合の上、適宜更新してください)
    
    private func estimatedCostJPY() -> (stt: Double, llm: Double, tts: Double, total: Double) {
        let sttCost = (usage.sttAudioSeconds ?? 0) / 60.0 * PricingJPY.sttPerMinute // sttAudioSecondsがnilなら0円

        var llmCost: Double = 0
        if let provider = usage.llmProvider {
            let pricing = PricingJPY.llmPricing(for: provider)
            let inputCost = Double(usage.llmInputTokens ?? 0) / 1_000_000.0 * pricing.input
            let outputCost = Double(usage.llmOutputTokens ?? 0) / 1_000_000.0 * pricing.output
            llmCost = inputCost + outputCost
        }
        
        let ttsCost = Double(usage.ttsCharacterCount ?? 0) / 1_000_000.0 * PricingJPY.ttsPerMillionCharacters
        
        let total = sttCost + llmCost + ttsCost
        return (sttCost, llmCost, ttsCost, total)
    }

    // 保存用にコスト情報をまとめて取り出す
    func makeTurnCost() -> TurnCost {
        let cost = estimatedCostJPY()
        let providerName: String? = usage.llmProvider.map { $0 == .openAI ? "ChatGPT" : "Claude" }
        
        return TurnCost(
            sttAudioSeconds: usage.sttAudioSeconds,
            llmInputTokens: usage.llmInputTokens,
            llmOutputTokens: usage.llmOutputTokens,
            llmProviderName: providerName,
            ttsCharacterCount: usage.ttsCharacterCount,
            sttCostJPY: cost.stt,
            llmCostJPY: cost.llm,
            ttsCostJPY: cost.tts,
            totalCostJPY: cost.total
        )
    }

    // MARK: - サマリー出力
    
    func printSummary() {
        let totalDuration = Date().timeIntervalSince(turnStartedAt)
        let cost = estimatedCostJPY()
        
        print("――――――――――――――――――――――――――――――")
        print("会話ターン サマリー [\(turnID)]")
        for phase in Phase.allCases {
            if let duration = timings[phase]?.duration {  // ← STTが計測されていなければここでスキップされる
                print(String(format: "  %@: %.3f秒", phase.rawValue, duration))
            }
        }
        print(String(format: "  合計時間(発話開始〜応答再生完了): %.3f秒", totalDuration))
        print("  --- 使用量 ---")
        if let seconds = usage.sttAudioSeconds {
            print(String(format: "  STT音声長: %.1f秒", seconds))
        }
        if let input = usage.llmInputTokens, let output = usage.llmOutputTokens, let provider = usage.llmProvider {
            let providerName = provider == .openAI ? "ChatGPT" : "Claude"
            print("  LLMトークン(\(providerName)): 入力\(input) / 出力\(output)")
        }
        if let chars = usage.ttsCharacterCount {
            print("  TTS文字数: \(chars)文字")
        }
        print("  --- 概算コスト ---")
        print(String(format: "  STT: ¥%.3f", cost.stt))
        print(String(format: "  LLM: ¥%.3f", cost.llm))
        print(String(format: "  TTS: ¥%.3f", cost.tts))
        print(String(format: "  合計: ¥%.3f", cost.total))
        print("――――――――――――――――――――――――――――――")
    }
}
