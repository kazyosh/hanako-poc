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
    @State private var morningPrompt = Hanako.shared.settings.morningPrompt
    @State private var afternoonPrompt = Hanako.shared.settings.afternoonPrompt
    @State private var eveningPrompt = Hanako.shared.settings.eveningPrompt
    @State private var isOn = true
    @State private var isShowingSettings = false
    @State private var selectedOption = "Claude"

    private let options = ["Claude", "ChatGPT"]

    var body: some View {
        NavigationStack {
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
                Text("朝")
                    .font(.title2)
                TextField(
                    "prompt",
                    text: $morningPrompt,
                    axis: .vertical
                )
                Button {
                    var settings = Hanako.shared.settings
                    settings.morningPrompt = morningPrompt
                    settings.save()
                    talkRightNow(timeOfDay: .morning)
                } label: {
                    Text("今話す")
                }
                Divider()
                Text("昼").font(.title3)
                TextField(
                    "prompt",
                    text: $afternoonPrompt,
                    axis: .vertical
                )
                Button {
                    var settings = Hanako.shared.settings
                    settings.afternoonPrompt = afternoonPrompt
                    settings.save()
                    talkRightNow(timeOfDay: .afternoon)
                } label: {
                    Text("今話す")
                }
                Divider()
                Text("夕").font(.title3)
                TextField(
                    "prompt",
                    text: $eveningPrompt,
                    axis: .vertical
                )
                Button {
                    var settings = Hanako.shared.settings
                    settings.eveningPrompt = eveningPrompt
                    settings.save()
                    talkRightNow(timeOfDay: .evening)
                } label: {
                    Text("今話す")
                }
            }
            .padding()
            .navigationTitle("はなこさん")
            .toolbar {
                 ToolbarItem(placement: .topBarTrailing) {
                     Button {
                         isShowingSettings = true
                     } label: {
                         Image(systemName: "gearshape")
                     }
                 }
             }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(conversationManager: Hanako.shared.manager)
            }
        }

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
