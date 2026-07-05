//
//  ModifiedApp.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 05/07/26.
//

import Foundation

struct ModifiedApp: Identifiable, Equatable {
    let id: String
    let url: URL
    var displayName: String

    init(url: URL) {
        self.id = url.path(percentEncoded: false)
        self.url = url
        self.displayName = url.deletingPathExtension().lastPathComponent
    }
}

enum IconApplyMode: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "Automático"
        case .light:
            "Claro"
        case .dark:
            "Escuro"
        case .original:
            "Original"
        }
    }
}
