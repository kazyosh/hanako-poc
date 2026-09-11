//
//  SettingsView.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/26.
//

import SwiftUI

struct SliderSettingRow: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    let valueLabel: (Float) -> String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title): \(valueLabel(value))")
                .font(.subheadline)
            
            Slider(value: $value, in: range, step: step)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct HourAndMinuteRow: View {
    let title: String
    @Binding var value: Date
    var body: some View {
        DatePicker(title, selection: $value, displayedComponents: .hourAndMinute)
    }
}

struct SettingsView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Environment(\.dismiss) private var dismiss

    // 保存ボタンが押されるまではこちらの値だけを操作する
    @State private var draft: AppSettings
    @State private var isSaved = false

    init(conversationManager: ConversationManager) {
        self.conversationManager = conversationManager
        _draft = State(initialValue: Hanako.shared.settings)
    }

    private var hasChanges: Bool {
        draft != Hanako.shared.settings
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SliderSettingRow(
                        title: "無音検出のしきい値",
                        value: $draft.silenceThreshold,
                        range: -90...(-20),
                        step: 1,
                        valueLabel: { "\(Int($0)) dB" },
                        description: "値が大きいほど、より大きな声でないと発話と判定されません。"
                    )
                    
                    SliderSettingRow(
                        title: "発話終了とみなす無音時間",
                        value: Binding(
                            get: { Float(draft.endOfSpeechSilenceDuration) },
                            set: { draft.endOfSpeechSilenceDuration = TimeInterval($0) }
                        ),
                        range: 0.5...3.0,
                        step: 0.1,
                        valueLabel: { String(format: "%.1f秒", $0) },
                        description: "この時間だけ無音が続くと、発話が終わったと判定します。"
                    )
                    
                    SliderSettingRow(
                        title: "会話タイムアウト",
                        value: Binding(
                            get: { Float(draft.conversationTimeoutDuration) },
                            set: { draft.conversationTimeoutDuration = TimeInterval($0) }
                        ),
                        range: 10...60,
                        step: 5,
                        valueLabel: { "\(Int($0))秒" },
                        description: "この時間ユーザーが話しかけてこない場合、会話を終了します。"
                    )
                }
                Section("毎日の声かけ") {
                    Toggle("有効にする", isOn: $draft.isDailyGreetingEnabled)
                    
                    if draft.isDailyGreetingEnabled {
                        ForEach($draft.greetingTimes) { $greetingTime in
                            HStack {
                                Text(greetingTime.label)
                                    .frame(width: 60, alignment: .leading)
                                
                                Spacer()
                                
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            var components = DateComponents()
                                            components.hour = greetingTime.hour
                                            components.minute = greetingTime.minute
                                            return Calendar.current.date(from: components) ?? Date()
                                        },
                                        set: { newDate in
                                            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                            greetingTime.hour = components.hour ?? greetingTime.hour
                                            greetingTime.minute = components.minute ?? greetingTime.minute
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }
                        }
                    }
                }
                Section("音声") {
                    Picker("声の種類", selection: $draft.voiceName) {
                        ForEach(VoiceOption.all) { voice in
                            Text(voice.displayName).tag(voice.name)
                        }
                    }
                    Button("この声で試し聞きする") {
                        Task {
                            await conversationManager.previewVoice(draft.voiceName)
                        }
                    }
                }
                Section {
                    Button {
                        Hanako.shared.settings = draft
                        isSaved = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(isSaved ? "保存しました" : "保存")
                            Spacer()
                        }
                    }
                    .disabled(!hasChanges)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
