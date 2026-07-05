//
//  ContentView.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 04/07/26.
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedAppURL: URL?
    @State private var selectedAppIcon: NSImage?
    @State private var lightIcon: NSImage?
    @State private var darkIcon: NSImage?
    @State private var generatedDarkIcon: NSImage?
    @State private var darkBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
    @State private var brightness = -0.08
    @State private var contrast = 1.12
    @State private var saturation = 0.86
    @State private var iconScale = 0.78
    @State private var invertColors = false
    @State private var statusMessage = "Selecione um app para começar."
    @State private var statusKind: StatusKind = .neutral

    private let iconRenderer = IconRenderer()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 980, minHeight: 650)
        .onChange(of: brightness) { _, _ in regenerateDarkIcon() }
        .onChange(of: contrast) { _, _ in regenerateDarkIcon() }
        .onChange(of: saturation) { _, _ in regenerateDarkIcon() }
        .onChange(of: iconScale) { _, _ in regenerateDarkIcon() }
        .onChange(of: invertColors) { _, _ in regenerateDarkIcon() }
        .onChange(of: darkBackground) { _, _ in regenerateDarkIcon() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon Changer")
                    .font(.title2.weight(.semibold))
                Text("Escolha um aplicativo, importe ícones ou gere uma versão escura a partir do ícone atual.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button {
                selectApplication()
            } label: {
                Label("Selecionar app", systemImage: "app.dashed")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            selectedApplicationSummary

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    importLightIcon()
                } label: {
                    Label("Ícone claro", systemImage: "sun.max")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedAppURL == nil)

                Button {
                    importDarkIcon()
                } label: {
                    Label("Ícone escuro", systemImage: "moon")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedAppURL == nil)

                Button {
                    generateDarkIconFromSelectedApp()
                } label: {
                    Label("Gerar escuro do app", systemImage: "wand.and.sparkles")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedAppIcon == nil)
            }
            .buttonStyle(.bordered)

            Spacer()

            statusView
        }
        .padding(22)
        .navigationSplitViewColumnWidth(min: 280, ideal: 310, max: 360)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                previewSection
                generatorSection
                applySection
            }
            .padding(28)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var selectedApplicationSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aplicativo")
                .font(.headline)

            HStack(spacing: 12) {
                iconImage(selectedAppIcon, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedAppURL?.deletingPathExtension().lastPathComponent ?? "Nenhum app selecionado")
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(selectedAppURL?.path(percentEncoded: false) ?? "Use o botão acima para escolher um .app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prévia")
                .font(.title3.weight(.semibold))

            HStack(spacing: 16) {
                IconPreview(title: "Atual", image: selectedAppIcon, fallbackSymbol: "app")
                IconPreview(title: "Claro", image: lightIcon, fallbackSymbol: "sun.max")
                IconPreview(title: "Escuro", image: darkIcon ?? generatedDarkIcon, fallbackSymbol: "moon")
            }
        }
    }

    private var generatorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gerador do Tema Escuro")
                .font(.title3.weight(.semibold))

            VStack(spacing: 14) {
                ColorPicker("Fundo", selection: $darkBackground, supportsOpacity: true)

                sliderRow("Brilho", value: $brightness, range: -0.45...0.25, format: "%.2f")
                sliderRow("Contraste", value: $contrast, range: 0.75...1.7, format: "%.2f")
                sliderRow("Saturação", value: $saturation, range: 0...1.6, format: "%.2f")
                sliderRow("Escala", value: $iconScale, range: 0.55...0.95, format: "%.2f")

                Toggle("Inverter cores antes dos ajustes", isOn: $invertColors)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var applySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aplicar")
                .font(.title3.weight(.semibold))

            Text("O macOS permite aplicar um ícone customizado ao app selecionado. A API pública não troca automaticamente entre variantes claro e escuro para aplicativos de terceiros; aplique a variante desejada quando quiser mudar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button {
                    apply(icon: lightIcon, label: "claro")
                } label: {
                    Label("Aplicar claro", systemImage: "sun.max.fill")
                }
                .disabled(selectedAppURL == nil || lightIcon == nil)

                Button {
                    apply(icon: darkIcon ?? generatedDarkIcon, label: "escuro")
                } label: {
                    Label("Aplicar escuro", systemImage: "moon.fill")
                }
                .disabled(selectedAppURL == nil || (darkIcon ?? generatedDarkIcon) == nil)

                Button(role: .destructive) {
                    resetCustomIcon()
                } label: {
                    Label("Restaurar original", systemImage: "arrow.counterclockwise")
                }
                .disabled(selectedAppURL == nil)
            }
            .buttonStyle(.bordered)
        }
    }

    private var statusView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusKind.symbolName)
                .foregroundStyle(statusKind.color)
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 74, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func iconImage(_ image: NSImage?, size: CGFloat) -> some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func selectApplication() {
        guard let url = openPanel(allowedContentTypes: [.application], canChooseDirectories: true) else {
            return
        }

        selectedAppURL = url
        selectedAppIcon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        lightIcon = nil
        darkIcon = nil
        generatedDarkIcon = nil
        status(.success, "App selecionado: \(url.lastPathComponent)")
    }

    private func importLightIcon() {
        guard let image = selectImage() else { return }
        lightIcon = iconRenderer.normalizedIcon(from: image)
        status(.success, "Ícone claro importado.")
    }

    private func importDarkIcon() {
        guard let image = selectImage() else { return }
        darkIcon = iconRenderer.normalizedIcon(from: image)
        status(.success, "Ícone escuro importado.")
    }

    private func generateDarkIconFromSelectedApp() {
        regenerateDarkIcon()
        status(.success, "Ícone escuro gerado a partir do app selecionado.")
    }

    private func regenerateDarkIcon() {
        guard let selectedAppIcon else { return }
        generatedDarkIcon = iconRenderer.darkVariant(
            from: selectedAppIcon,
            background: NSColor(darkBackground),
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            scale: iconScale,
            invertColors: invertColors
        )
    }

    private func apply(icon: NSImage?, label: String) {
        guard let selectedAppURL, let icon else { return }

        let didAccess = selectedAppURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                selectedAppURL.stopAccessingSecurityScopedResource()
            }
        }

        let path = selectedAppURL.path(percentEncoded: false)
        if NSWorkspace.shared.setIcon(icon, forFile: path, options: []) {
            selectedAppIcon = NSWorkspace.shared.icon(forFile: path)
            status(.success, "Ícone \(label) aplicado. Talvez seja necessário reiniciar o Dock/Finder para ver a mudança.")
        } else {
            status(.error, "Não foi possível aplicar o ícone. Verifique se o app selecionado permite escrita pelo seu usuário.")
        }
    }

    private func resetCustomIcon() {
        guard let selectedAppURL else { return }

        let path = selectedAppURL.path(percentEncoded: false)
        if NSWorkspace.shared.setIcon(nil, forFile: path, options: []) {
            selectedAppIcon = NSWorkspace.shared.icon(forFile: path)
            status(.success, "Ícone customizado removido.")
        } else {
            status(.error, "Não foi possível restaurar o ícone original.")
        }
    }

    private func selectImage() -> NSImage? {
        guard let url = openPanel(allowedContentTypes: [.image], canChooseDirectories: false) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }

    private func openPanel(allowedContentTypes: [UTType], canChooseDirectories: Bool) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = canChooseDirectories
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func status(_ kind: StatusKind, _ message: String) {
        statusKind = kind
        statusMessage = message
    }
}

private struct IconPreview: View {
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

private enum StatusKind {
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

private final class IconRenderer {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let iconSize = CGSize(width: 1024, height: 1024)

    func normalizedIcon(from image: NSImage) -> NSImage {
        render(size: iconSize) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    func darkVariant(
        from image: NSImage,
        background: NSColor,
        brightness: Double,
        contrast: Double,
        saturation: Double,
        scale: Double,
        invertColors: Bool
    ) -> NSImage {
        let normalized = normalizedIcon(from: image)
        let processed = process(
            normalized,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            invertColors: invertColors
        )

        return render(size: iconSize) { rect in
            background.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210).fill()

            let side = rect.width * scale
            let iconRect = CGRect(
                x: rect.midX - side / 2,
                y: rect.midY - side / 2,
                width: side,
                height: side
            )
            processed.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    private func process(
        _ image: NSImage,
        brightness: Double,
        contrast: Double,
        saturation: Double,
        invertColors: Bool
    ) -> NSImage {
        guard var ciImage = CIImage(data: image.tiffRepresentation ?? Data()) else {
            return image
        }

        if invertColors {
            let invertFilter = CIFilter.colorInvert()
            invertFilter.inputImage = ciImage
            if let outputImage = invertFilter.outputImage {
                ciImage = outputImage
            }
        }

        let controlsFilter = CIFilter.colorControls()
        controlsFilter.inputImage = ciImage
        controlsFilter.brightness = Float(brightness)
        controlsFilter.contrast = Float(contrast)
        controlsFilter.saturation = Float(saturation)

        guard
            let outputImage = controlsFilter.outputImage,
            let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            return image
        }

        return NSImage(cgImage: cgImage, size: image.size)
    }

    private func render(size: CGSize, draw: (CGRect) -> Void) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(CGRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}

#Preview {
    ContentView()
}
