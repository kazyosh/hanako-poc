import Foundation

// 1ターン分の計測を保持する値。ConversationManager側で生成し、各処理に渡す。
final class ConversationTurnLog {
    enum Phase: String, CaseIterable {
        case stt = "STT"
        case llm = "LLM"
        case tts = "TTS"
        case networkLLM = "LLM通信(RTT)"
        case networkTTS = "TTS通信(RTT)"
    }
    
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
    private let turnID = UUID().uuidString.prefix(8) // ログの見分け用
    
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
    
    func printSummary() {
        let totalDuration = Date().timeIntervalSince(turnStartedAt)
        
        print("――――――――――――――――――――――――――――――")
        print("会話ターン サマリー [\(turnID)]")
        for phase in Phase.allCases {
            if let duration = timings[phase]?.duration {
                print(String(format: "  %@: %.3f秒", phase.rawValue, duration))
            }
        }
        print(String(format: "  合計(発話開始〜応答再生完了): %.3f秒", totalDuration))
        print("――――――――――――――――――――――――――――――")
    }
}
