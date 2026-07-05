//
//  StatusKind.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 04/07/26.
//

import SwiftUI

enum StatusKind {
    case neutral
    case success
    case error

    var symbolName: String {
        switch self {
        case .neutral:
            "info.circle"
        case .success:
            "checkmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .neutral:
            .secondary
        case .success:
            .green
        case .error:
            .red
        }
    }
}
