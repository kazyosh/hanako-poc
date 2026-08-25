//
//  Settings.swift
//  hanako-poc
//
//  Created by 吉田 和裕 on 2026/08/20.
//

import Foundation

struct Settings {
    var morning: Date {
        didSet {
            UserDefaults.standard.set(morning, forKey: "morning")
        }
    }
    var morningPrompt: String {
        didSet {
            UserDefaults.standard.set(morningPrompt, forKey: "morningPrompt")
        }
    }
    var afternoon: Date {
        didSet {
            UserDefaults.standard.set(afternoon, forKey: "afternoon")
        }
    }
    var afternoonPrompt: String {
        didSet {
            UserDefaults.standard.set(afternoonPrompt, forKey: "afternoonPrompt")
        }
    }
    var evening: Date {
        didSet {
            UserDefaults.standard.set(evening, forKey: "evening")
        }
    }
    var eveningPrompt: String {
        didSet {
            UserDefaults.standard.set(eveningPrompt, forKey: "eveningPrompt")
        }
    }

    init() {
        morning = UserDefaults.standard.object(forKey: "morning") as? Date ?? Date()
        morningPrompt = UserDefaults.standard.string(forKey: "morningPrompt") ?? "朝の挨拶を一言、親しみやすく自然な日本語で作って。長さは20文字程度。"
        afternoon = UserDefaults.standard.object(forKey: "afternoon") as? Date ?? Date()
        afternoonPrompt = UserDefaults.standard.string(forKey: "afternoonPrompt") ?? "昼の挨拶を一言、親しみやすく自然な日本語で作って。長さは20文字程度。"
        evening = UserDefaults.standard.object(forKey: "evening") as? Date ?? Date()
        eveningPrompt = UserDefaults.standard.string(forKey: "eveningPrompt") ?? "夕方の挨拶を一言、親しみやすく自然な日本語で作って。長さは20文字程度。"
    }
}
