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
    var importAction: (() -> Void)?
    var deleteAction: (() -> Void)?

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
            .overlay(alignment: .topLeading) {
                if let importAction {
                    Button {
                        importAction()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Importar ícone")
                    .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let deleteAction, image != nil {
                    Button(role: .destructive) {
                        deleteAction()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Remover ícone")
                    .padding(8)
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
