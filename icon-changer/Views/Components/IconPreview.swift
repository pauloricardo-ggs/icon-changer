//
//  IconPreview.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 04/07/26.
//

import AppKit
import SwiftUI

struct IconPreview: View {
    let title: String
    let image: NSImage?
    let fallbackSymbol: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                } else {
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 180)

            Text(title)
                .font(.callout.weight(.medium))
        }
        .frame(maxWidth: .infinity)
    }
}
