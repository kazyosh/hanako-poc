//
//  ContentView.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/20.
//

import SwiftUI

struct Checkbox: View {
    var text: String
    @Binding var isSelected: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected == text ? "checkmark.circle" : "circle")
                    .foregroundColor(.accentColor)
                Text(text)
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject private var conversationManager = Hanako.shared.manager
    @State private var morningPrompt = Hanako.shared.settings.morningPrompt
    @State private var afternoonPrompt = Hanako.shared.settings.afternoonPrompt
    @State private var eveningPrompt = Hanako.shared.settings.eveningPrompt
    @State private var isOn = true
    @State private var isShowingSettings = false
    @State private var selectedOption = "Claude"

    private let options = ["Claude", "ChatGPT"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack {
                        HStack {
                            ForEach(options, id: \.self) { option in
                                Checkbox(text: option, isSelected: $selectedOption, onTap: {
                                    selectedOption = option
                                })
                            }
                        }
                        Text("話しかける内容を設定してください")
                            .font(.default).padding()
                        HStack {
                            Text("朝")
                                .font(.title2).padding()
                            TextField(
                                "prompt",
                                text: $morningPrompt,
                                axis: .vertical
                            )
                            .onSubmit { savePrompts() }
                        }
                        Button {
                            savePrompts()
                            talkRightNow(timeOfDay: .morning)
                        } label: {
                            Text("今話す")
                        }
                        Divider()
                        HStack {
                            Text("昼").font(.title2).padding()
                            TextField(
                                "prompt",
                                text: $afternoonPrompt,
                                axis: .vertical
                            )
                            .onSubmit { savePrompts() }
                        }
                        Button {
                            savePrompts()
                            talkRightNow(timeOfDay: .afternoon)
                        } label: {
                            Text("今話す")
                        }
                        Divider()
                        HStack{
                            Text("夕").font(.title2).padding()
                            TextField(
                                "prompt",
                                text: $eveningPrompt,
                                axis: .vertical
                            )
                            .onSubmit { savePrompts() }
                        }
                        Button {
                            savePrompts()
                            talkRightNow(timeOfDay: .evening)
                        } label: {
                            Text("今話す")
                        }
                    }
                    .padding()
                }
                
                ConversationStatusBar(state: conversationManager.conversationState)
            }
            .navigationTitle("はなこさん")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                     Button {
                         isShowingSettings = true
                     } label: {
                         Image(systemName: "gearshape")
                     }
                 }
             }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(conversationManager: conversationManager)
            }
            .onDisappear {
                savePrompts()
            }
        }
    }
    
    // 3つのプロンプトをまとめてHanako.shared.settingsへ反映する
    private func savePrompts() {
        var newSettings = Hanako.shared.settings
        newSettings.morningPrompt = morningPrompt
        newSettings.afternoonPrompt = afternoonPrompt
        newSettings.eveningPrompt = eveningPrompt
        Hanako.shared.settings = newSettings  // didSetでsave() + 各種反映が自動的に走る
    }
    
    func talkRightNow(timeOfDay: TimeOfDay) {
        Task {
            do {
                if selectedOption == "Claude" {
                    Hanako.shared.useClaudeAPI()
                }
                else {
                    Hanako.shared.useOpenAIAPI()
                }
                await Hanako.shared.startGreeting(timeOfDay: timeOfDay)
            }
        }
    }
}

#Preview {
    ContentView()
}
