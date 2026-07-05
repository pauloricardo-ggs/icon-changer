//
//  StatusView.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 04/07/26.
//

import SwiftUI

struct StatusView: View {
    let kind: StatusKind
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.symbolName)
                .foregroundStyle(kind.color)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
