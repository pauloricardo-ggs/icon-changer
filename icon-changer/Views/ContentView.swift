//
//  ContentView.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 04/07/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedAppURL: URL?
    @State private var selectedAppIcon: NSImage?
    @State private var lightIcon: NSImage?
    @State private var darkIcon: NSImage?
    @State private var generatedDarkIcon: NSImage?
    @State private var usesBackground = false
    @State private var darkBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
    @State private var brightness = -0.42
    @State private var contrast = 0.95
    @State private var saturation = 0.86
    @State private var iconScale = 1.0
    @State private var invertColors = false
    @State private var statusMessage = "Selecione um app para começar."
    @State private var statusKind: StatusKind = .neutral
    @State private var generationTask: Task<Void, Never>?

    private let iconRenderer = IconRenderer()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 320)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            detail
        }
        .frame(minWidth: 980, minHeight: 650)
        .onChange(of: brightness) { _, _ in scheduleDarkIconRegeneration() }
        .onChange(of: contrast) { _, _ in scheduleDarkIconRegeneration() }
        .onChange(of: saturation) { _, _ in scheduleDarkIconRegeneration() }
        .onChange(of: iconScale) { _, _ in scheduleDarkIconRegeneration() }
        .onChange(of: invertColors) { _, _ in scheduleDarkIconRegeneration() }
        .onChange(of: usesBackground) { _, _ in scheduleDarkIconRegeneration() }
        .onChange(of: darkBackground) { _, _ in scheduleDarkIconRegeneration() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            appHeader

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

            Spacer()

            StatusView(kind: statusKind, message: statusMessage)
        }
        .padding(22)
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

    private var appHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon Changer")
                .font(.title2.weight(.semibold))
            Text("Escolha um aplicativo, importe ícones ou gere uma versão escura a partir do ícone atual.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                IconPreview(
                    title: "Claro",
                    image: lightIcon,
                    fallbackSymbol: "sun.max",
                    importAction: importLightIcon,
                    deleteAction: clearLightIcon
                )
                IconPreview(
                    title: "Escuro",
                    image: generatedDarkIcon ?? darkIcon,
                    fallbackSymbol: "moon",
                    importAction: importDarkIcon,
                    deleteAction: clearDarkIcon
                )
            }
        }
    }

    private var generatorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ícone Escuro Gerado")
                .font(.title3.weight(.semibold))

            VStack(spacing: 14) {
                Toggle("Usar fundo", isOn: $usesBackground)

                ColorPicker("Fundo", selection: $darkBackground, supportsOpacity: true)
                    .disabled(!usesBackground)

                sliderRow("Brilho fundo", value: $brightness, range: -0.55...0.15, format: "%.2f")
                sliderRow("Contraste fundo", value: $contrast, range: 0.75...1.7, format: "%.2f")
                sliderRow("Saturação fundo", value: $saturation, range: 0...1.6, format: "%.2f")
                sliderRow("Escala", value: $iconScale, range: 0.65...1.0, format: "%.2f")

                Toggle("Inverter cores antes dos ajustes", isOn: $invertColors)

                HStack(spacing: 12) {
                    Button {
                        resetDarkGeneratorAdjustments()
                    } label: {
                        Label("Resetar ajustes", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        generateDarkIconFromSelectedApp()
                    } label: {
                        Label("Gerar ícone escuro", systemImage: "wand.and.sparkles")
                    }
                    .disabled(selectedAppIcon == nil)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .trailing)
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
                    applyCurrentIcon()
                } label: {
                    Label("Aplicar", systemImage: "paintbrush.pointed.fill")
                }
                .disabled(selectedAppURL == nil || currentApplicableIcon == nil)

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

    private var currentApplicableIcon: NSImage? {
        if isSystemDarkMode {
            generatedDarkIcon ?? darkIcon ?? lightIcon
        } else {
            lightIcon ?? generatedDarkIcon ?? darkIcon
        }
    }

    private var isSystemDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
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

    private func clearLightIcon() {
        lightIcon = nil
        status(.neutral, "Ícone claro removido.")
    }

    private func clearDarkIcon() {
        darkIcon = nil
        generatedDarkIcon = nil
        status(.neutral, "Ícone escuro removido.")
    }

    private func resetDarkGeneratorAdjustments() {
        usesBackground = false
        darkBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
        brightness = -0.42
        contrast = 0.95
        saturation = 0.86
        iconScale = 1.0
        invertColors = false
        regenerateDarkIcon()
        status(.neutral, "Ajustes do ícone escuro resetados.")
    }

    private func scheduleDarkIconRegeneration() {
        guard generatedDarkIcon != nil else { return }

        generationTask?.cancel()
        generationTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            regenerateDarkIcon()
        }
    }

    private func generateDarkIconFromSelectedApp() {
        generationTask?.cancel()
        darkIcon = nil
        regenerateDarkIcon()
        status(.success, "Ícone escuro gerado a partir do app selecionado.")
    }

    private func regenerateDarkIcon() {
        guard let selectedAppIcon else { return }
        generatedDarkIcon = iconRenderer.darkVariant(
            from: selectedAppIcon,
            background: usesBackground ? NSColor(darkBackground) : nil,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            scale: iconScale,
            invertColors: invertColors
        )
    }

    private func applyCurrentIcon() {
        guard let selectedAppURL, let icon = currentApplicableIcon else { return }

        let didAccess = selectedAppURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                selectedAppURL.stopAccessingSecurityScopedResource()
            }
        }

        let path = selectedAppURL.path(percentEncoded: false)
        if NSWorkspace.shared.setIcon(icon, forFile: path, options: []) {
            selectedAppIcon = NSWorkspace.shared.icon(forFile: path)
            restartDockAfterApplyingIcon()
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

    private func restartDockAfterApplyingIcon() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                status(.success, "Ícone aplicado e Dock reiniciado.")
            } else {
                status(.success, "Ícone aplicado, mas não foi possível reiniciar o Dock automaticamente.")
            }
        } catch {
            status(.success, "Ícone aplicado, mas não foi possível reiniciar o Dock automaticamente.")
        }
    }
}

#Preview {
    ContentView()
}
