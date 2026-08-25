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
    @State private var morning = Settings().morning
    @State private var morningPrompt = Settings().morningPrompt
    @State private var afternoon = Settings().afternoon
    @State private var afternoonPrompt = Settings().afternoonPrompt
    @State private var evening = Settings().evening
    @State private var eveningPrompt = Settings().eveningPrompt
    @State private var isOn = true
    @State private var selectedOption = "Claude"

    private let options = ["Claude", "ChatGPT"]

    var body: some View {
        VStack {
            Text("はなこさん")
                .font(.largeTitle)
            HStack {
                ForEach(options, id: \.self) { option in
                    Checkbox(text: option, isSelected: $selectedOption, onTap: {
                        selectedOption = option
                    })
                }
            }
            Text("話しかける内容、時刻を設定してください")
                .font(.default).padding()
            Text("朝")
                .font(.title2)
            DatePicker("時刻", selection: $morning, displayedComponents: .hourAndMinute)
            TextField(
                "prompt",
                text: $morningPrompt,
                axis: .vertical
            )
            Button {
                talkRightNow(timeOfDay: .morning)
            } label: {
                Text("今話す")
            }
            Divider()
            Text("昼").font(.title3)
            DatePicker("時刻", selection: $afternoon, displayedComponents: .hourAndMinute)
                .padding()
            TextField(
                "prompt",
                text: $afternoonPrompt,
                axis: .vertical
            )
            Button {
                talkRightNow(timeOfDay: .afternoon)
            } label: {
                Text("今話す")
            }
            Divider()
            Text("夕").font(.title3)
            DatePicker("時刻", selection: $evening, displayedComponents: .hourAndMinute)
                .padding()
            TextField(
                "prompt",
                text: $eveningPrompt,
                axis: .vertical
            )
            Button {
                talkRightNow(timeOfDay: .evening)
            } label: {
                Text("今話す")
            }
            Divider()
            Button {
                updateSettings()
            } label: {
                Text("決定")
            }

        }
        .padding()
    }
    
    func talkRightNow(timeOfDay: TimeOfDay) {
        Task {
            do {
                updateSettings()
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

    func updateSettings() {
        var settings = Settings()
        settings.morning = morning
        settings.afternoon = afternoon
        settings.evening = evening
        settings.morningPrompt = morningPrompt
        settings.afternoonPrompt = afternoonPrompt
        settings.eveningPrompt = eveningPrompt
    }
}

#Preview {
    ContentView()
}
