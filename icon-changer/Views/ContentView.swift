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
    private enum IconChoice {
        case custom(NSImage)
        case original
    }

    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedAppURL: URL?
    @State private var selectedAppIcon: NSImage?
    @State private var originalAppIcon: NSImage?
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
    @State private var switchesIconWithSystemAppearance = true
    @State private var keepsMonitoringInBackground = false
    @State private var staysInMenuBar = false
    @State private var refreshesDockAutomatically = false
    @State private var applyMode: IconApplyMode = .automatic
    @State private var modifiedApps: [ModifiedApp] = []
    @State private var isShowingDarkIconGenerator = false
    @State private var draftGeneratedDarkIcon: NSImage?
    @State private var draftUsesBackground = false
    @State private var draftDarkBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
    @State private var draftBrightness = -0.42
    @State private var draftContrast = 0.95
    @State private var draftSaturation = 0.86
    @State private var draftIconScale = 1.0
    @State private var draftInvertColors = false
    @State private var draftGenerationTask: Task<Void, Never>?

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
        .onChange(of: colorScheme) { _, _ in applyIconForSystemAppearanceChange() }
        .onChange(of: switchesIconWithSystemAppearance) { _, _ in syncIconSwitchingMonitor() }
        .onChange(of: refreshesDockAutomatically) { _, _ in syncIconSwitchingMonitor() }
        .onChange(of: keepsMonitoringInBackground) { _, isEnabled in
            IconSwitchingMonitor.shared.setEnabled(isEnabled)
            syncIconSwitchingMonitor()
            status(.neutral, isEnabled ? "Monitoramento em segundo plano ativado enquanto o app estiver rodando." : "Monitoramento em segundo plano desativado.")
        }
        .onChange(of: staysInMenuBar) { _, isEnabled in
            NotificationCenter.default.post(name: .iconChangerMenuBarModeChanged, object: isEnabled)
            status(.neutral, isEnabled ? "Menu bar ativado. Ao fechar a janela, o app continuará no menu bar." : "Menu bar desativado.")
        }
        .sheet(isPresented: $isShowingDarkIconGenerator) {
            darkIconGeneratorSheet
        }
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

            modifiedAppsSection

            Spacer()

            StatusView(kind: statusKind, message: statusMessage)
        }
        .padding(22)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                previewSection
                generatorLauncherSection
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

    private var modifiedAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text("Apps modificados")
                .font(.headline)

            if modifiedApps.isEmpty {
                Text("Nenhum app modificado nesta sessão.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(modifiedApps) { app in
                            Button {
                                selectModifiedApp(app)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path(percentEncoded: false)))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Text(app.displayName)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                            .background(selectedAppURL == app.url ? Color.accentColor.opacity(0.16) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(maxHeight: 180)
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

    private var generatorLauncherSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ícone Escuro Gerado")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                Button {
                    openDarkIconGenerator()
                } label: {
                    Label(generatedDarkIcon == nil ? "Gerar ícone escuro" : "Editar ícone escuro", systemImage: "wand.and.sparkles")
                }
                .disabled(selectedAppIcon == nil)

                if generatedDarkIcon != nil {
                    Button(role: .destructive) {
                        generatedDarkIcon = nil
                        status(.neutral, "Ícone escuro gerado removido.")
                    } label: {
                        Label("Remover gerado", systemImage: "xmark")
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var applySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aplicar")
                .font(.title3.weight(.semibold))

            Text("O macOS permite aplicar um ícone customizado por vez ao app selecionado. Com a alternância automática ativa, o Icon Changer reaplica a variante clara ou escura quando detectar mudança no tema do sistema enquanto estiver aberto. Se uma variante não existir, o ícone original é usado.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Ícone utilizado", selection: $applyMode) {
                ForEach(IconApplyMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Alternar automaticamente ao mudar o tema do sistema", isOn: $switchesIconWithSystemAppearance)
            Toggle("Continuar monitorando em segundo plano", isOn: $keepsMonitoringInBackground)
            Toggle("Ficar no menu bar e esconder da Dock", isOn: $staysInMenuBar)
            Toggle("Tentar atualizar Dock automaticamente", isOn: $refreshesDockAutomatically)

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

    private var darkIconGeneratorSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Gerar Ícone Escuro")
                .font(.title2.weight(.semibold))

            HStack(alignment: .top, spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))

                    if let draftGeneratedDarkIcon {
                        Image(nsImage: draftGeneratedDarkIcon)
                            .resizable()
                            .scaledToFit()
                            .padding(24)
                    } else {
                        Image(systemName: "moon")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 220, height: 220)

                VStack(spacing: 14) {
                    Toggle("Usar fundo", isOn: $draftUsesBackground)

                    ColorPicker("Fundo", selection: $draftDarkBackground, supportsOpacity: true)
                        .disabled(!draftUsesBackground)

                    sliderRow("Brilho fundo", value: $draftBrightness, range: -0.55...0.15, format: "%.2f")
                    sliderRow("Contraste fundo", value: $draftContrast, range: 0.75...1.7, format: "%.2f")
                    sliderRow("Saturação fundo", value: $draftSaturation, range: 0...1.6, format: "%.2f")
                    sliderRow("Escala", value: $draftIconScale, range: 0.65...1.3, format: "%.2f")

                    Toggle("Inverter cores antes dos ajustes", isOn: $draftInvertColors)
                }
            }

            HStack {
                Button {
                    resetDraftDarkGeneratorAdjustments()
                } label: {
                    Label("Resetar ajustes", systemImage: "arrow.counterclockwise")
                }

                Spacer()

                Button {
                    draftGenerationTask?.cancel()
                    isShowingDarkIconGenerator = false
                } label: {
                    Text("Cancelar")
                }

                Button {
                    confirmDraftDarkIcon()
                } label: {
                    Label("Confirmar", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftGeneratedDarkIcon == nil)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(width: 720)
        .onAppear {
            regenerateDraftDarkIcon()
        }
        .onChange(of: draftUsesBackground) { _, _ in scheduleDraftDarkIconRegeneration() }
        .onChange(of: draftDarkBackground) { _, _ in scheduleDraftDarkIconRegeneration() }
        .onChange(of: draftBrightness) { _, _ in scheduleDraftDarkIconRegeneration() }
        .onChange(of: draftContrast) { _, _ in scheduleDraftDarkIconRegeneration() }
        .onChange(of: draftSaturation) { _, _ in scheduleDraftDarkIconRegeneration() }
        .onChange(of: draftIconScale) { _, _ in scheduleDraftDarkIconRegeneration() }
        .onChange(of: draftInvertColors) { _, _ in scheduleDraftDarkIconRegeneration() }
    }

    private var currentApplicableIcon: NSImage? {
        switch iconChoice(for: applyMode) {
        case .custom(let image):
            image
        case .original:
            originalAppIcon
        case nil:
            nil
        }
    }

    private var currentApplicableIconChoice: IconChoice? {
        iconChoice(for: applyMode)
    }

    private func iconChoice(for mode: IconApplyMode) -> IconChoice? {
        switch mode {
        case .automatic:
            return colorScheme == .dark ? iconChoice(for: .dark) : iconChoice(for: .light)
        case .light:
            if let lightIcon {
                return .custom(lightIcon)
            }
            return .original
        case .dark:
            if let darkIcon = generatedDarkIcon ?? darkIcon {
                return .custom(darkIcon)
            }
            return .original
        case .original:
            return .original
        }
    }

    private var currentThemeAutomaticIconChoice: IconChoice? {
        if colorScheme == .dark {
            iconChoice(for: .dark)
        } else {
            iconChoice(for: .light)
        }
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
        guard let url = openPanel(allowedContentTypes: [.application], canChooseDirectories: false) else {
            return
        }

        loadApplication(at: url, showsStatus: true)
    }

    private func selectModifiedApp(_ app: ModifiedApp) {
        loadApplication(at: app.url, showsStatus: true)
    }

    private func loadApplication(at url: URL, showsStatus: Bool = false) {
        guard let appURL = normalizedApplicationURL(from: url) else {
            status(.error, "Selecione um arquivo .app válido.")
            return
        }

        let path = appURL.path(percentEncoded: false)
        selectedAppURL = appURL
        let currentIcon = NSWorkspace.shared.icon(forFile: path)
        selectedAppIcon = currentIcon
        originalAppIcon = bundledApplicationIcon(for: appURL) ?? currentIcon
        lightIcon = nil
        darkIcon = nil
        generatedDarkIcon = nil
        syncIconSwitchingMonitor()

        if showsStatus {
            status(.success, "App selecionado: \(appURL.deletingPathExtension().lastPathComponent)")
        }
    }

    private func importLightIcon() {
        guard let image = selectImage() else { return }
        lightIcon = iconRenderer.normalizedIcon(from: image)
        syncIconSwitchingMonitor()
        status(.success, "Ícone claro importado.")
    }

    private func importDarkIcon() {
        guard let image = selectImage() else { return }
        darkIcon = iconRenderer.normalizedIcon(from: image)
        syncIconSwitchingMonitor()
        status(.success, "Ícone escuro importado.")
    }

    private func clearLightIcon() {
        lightIcon = nil
        syncIconSwitchingMonitor()
        status(.neutral, "Ícone claro removido.")
    }

    private func clearDarkIcon() {
        darkIcon = nil
        generatedDarkIcon = nil
        syncIconSwitchingMonitor()
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

    private func openDarkIconGenerator() {
        draftUsesBackground = usesBackground
        draftDarkBackground = darkBackground
        draftBrightness = brightness
        draftContrast = contrast
        draftSaturation = saturation
        draftIconScale = iconScale
        draftInvertColors = invertColors
        draftGeneratedDarkIcon = generatedDarkIcon
        isShowingDarkIconGenerator = true
    }

    private func resetDraftDarkGeneratorAdjustments() {
        draftUsesBackground = false
        draftDarkBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
        draftBrightness = -0.42
        draftContrast = 0.95
        draftSaturation = 0.86
        draftIconScale = 1.0
        draftInvertColors = false
        regenerateDraftDarkIcon()
    }

    private func regenerateDraftDarkIcon() {
        guard let sourceIcon = originalAppIcon ?? selectedAppIcon else { return }

        draftGeneratedDarkIcon = iconRenderer.darkVariant(
            from: sourceIcon,
            background: draftUsesBackground ? NSColor(draftDarkBackground) : nil,
            brightness: draftBrightness,
            contrast: draftContrast,
            saturation: draftSaturation,
            scale: draftIconScale,
            invertColors: draftInvertColors
        )
    }

    private func scheduleDraftDarkIconRegeneration() {
        guard isShowingDarkIconGenerator else { return }

        draftGenerationTask?.cancel()
        draftGenerationTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            regenerateDraftDarkIcon()
        }
    }

    private func confirmDraftDarkIcon() {
        guard let draftGeneratedDarkIcon else { return }

        draftGenerationTask?.cancel()
        usesBackground = draftUsesBackground
        darkBackground = draftDarkBackground
        brightness = draftBrightness
        contrast = draftContrast
        saturation = draftSaturation
        iconScale = draftIconScale
        invertColors = draftInvertColors
        darkIcon = nil
        generatedDarkIcon = draftGeneratedDarkIcon
        syncIconSwitchingMonitor()
        isShowingDarkIconGenerator = false
        status(.success, "Ícone escuro confirmado.")
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
        guard let sourceIcon = originalAppIcon ?? selectedAppIcon else { return }
        generatedDarkIcon = iconRenderer.darkVariant(
            from: sourceIcon,
            background: usesBackground ? NSColor(darkBackground) : nil,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            scale: iconScale,
            invertColors: invertColors
        )
    }

    private func applyCurrentIcon() {
        guard let selectedAppURL, let choice = currentApplicableIconChoice else { return }
        apply(choice: choice, to: selectedAppURL, successMessage: "Ícone aplicado.")
    }

    private func applyIconForSystemAppearanceChange() {
        guard switchesIconWithSystemAppearance, let selectedAppURL, let choice = currentThemeAutomaticIconChoice else {
            return
        }

        let themeName = colorScheme == .dark ? "escuro" : "claro"
        apply(choice: choice, to: selectedAppURL, successMessage: "Tema \(themeName) detectado. Ícone correspondente aplicado.")
    }

    private func apply(choice: IconChoice, to appURL: URL, successMessage: String) {
        switch choice {
        case .custom(let image):
            apply(icon: image, to: appURL, successMessage: successMessage)
        case .original:
            applyOriginalIcon(to: appURL, successMessage: successMessage)
        }
    }

    private func apply(icon: NSImage, to appURL: URL, successMessage: String) {
        let didAccess = appURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                appURL.stopAccessingSecurityScopedResource()
            }
        }

        let path = appURL.path(percentEncoded: false)
        if NSWorkspace.shared.setIcon(icon, forFile: path, options: []) {
            notifyIconChanged(at: path)
            registerModifiedApp(appURL)
            selectedAppIcon = NSWorkspace.shared.icon(forFile: path)
            syncIconSwitchingMonitor()
            if refreshesDockAutomatically {
                let didRefreshDock = refreshDock()
                status(
                    .success,
                    didRefreshDock
                        ? "\(successMessage) Dock atualizada."
                        : "\(successMessage) Não foi possível atualizar a Dock automaticamente; remova e adicione o app na Dock se ela continuar com cache."
                )
            } else {
                status(.success, "\(successMessage) Se o app estiver na Dock, remova e adicione-o novamente para atualizar o ícone da Dock.")
            }
        } else {
            status(.error, "Não foi possível aplicar o ícone. Verifique se o app selecionado permite escrita pelo seu usuário.")
        }
    }

    private func applyOriginalIcon(to appURL: URL, successMessage: String) {
        let didAccess = appURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                appURL.stopAccessingSecurityScopedResource()
            }
        }

        let path = appURL.path(percentEncoded: false)
        if NSWorkspace.shared.setIcon(nil, forFile: path, options: []) {
            notifyIconChanged(at: path)
            if hasCustomVariantConfigured {
                registerModifiedApp(appURL)
            } else {
                unregisterModifiedApp(appURL)
            }
            selectedAppIcon = NSWorkspace.shared.icon(forFile: path)
            syncIconSwitchingMonitor()
            status(.success, "\(successMessage) Ícone original restaurado. Se o app estiver na Dock, remova e adicione-o novamente para atualizar o ícone da Dock.")
        } else {
            status(.error, "Não foi possível restaurar o ícone original.")
        }
    }

    private func resetCustomIcon() {
        guard let selectedAppURL else { return }

        let path = selectedAppURL.path(percentEncoded: false)
        if NSWorkspace.shared.setIcon(nil, forFile: path, options: []) {
            notifyIconChanged(at: path)
            unregisterModifiedApp(selectedAppURL)
            selectedAppIcon = NSWorkspace.shared.icon(forFile: path)
            syncIconSwitchingMonitor()
            status(.success, "Ícone customizado removido. Se o app estiver na Dock, remova e adicione-o novamente para atualizar o ícone da Dock.")
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

    private var hasCustomVariantConfigured: Bool {
        lightIcon != nil || darkIcon != nil || generatedDarkIcon != nil
    }

    private func normalizedApplicationURL(from url: URL) -> URL? {
        var candidate = url.standardizedFileURL.resolvingSymlinksInPath()

        while candidate.path != candidate.deletingLastPathComponent().path {
            if candidate.pathExtension == "app", Bundle(url: candidate) != nil {
                return candidate
            }

            candidate = candidate.deletingLastPathComponent()
        }

        return nil
    }

    private func bundledApplicationIcon(for appURL: URL) -> NSImage? {
        guard let bundle = Bundle(url: appURL) else { return nil }

        let iconNames = bundledIconNames(from: bundle.infoDictionary ?? [:])
        for iconName in iconNames {
            if let image = bundledIcon(named: iconName, in: bundle) {
                return iconRenderer.normalizedIcon(from: image)
            }
        }

        return nil
    }

    private func bundledIconNames(from info: [String: Any]) -> [String] {
        var names: [String] = []

        if let iconFile = info["CFBundleIconFile"] as? String {
            names.append(iconFile)
        }

        if let iconName = info["CFBundleIconName"] as? String {
            names.append(iconName)
        }

        if
            let icons = info["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
        {
            names.append(contentsOf: iconFiles.reversed())
        }

        return Array(NSOrderedSet(array: names)) as? [String] ?? names
    }

    private func bundledIcon(named name: String, in bundle: Bundle) -> NSImage? {
        let nsName = name as NSString
        let baseName = nsName.deletingPathExtension
        let fileExtension = nsName.pathExtension.isEmpty ? "icns" : nsName.pathExtension

        let url = bundle.url(forResource: baseName, withExtension: fileExtension)
            ?? bundle.url(forResource: name, withExtension: nil)

        guard let url else { return nil }
        return NSImage(contentsOf: url)
    }

    private func status(_ kind: StatusKind, _ message: String) {
        statusKind = kind
        statusMessage = message
    }

    private func notifyIconChanged(at path: String) {
        NSWorkspace.shared.noteFileSystemChanged(path)
    }

    private func refreshDock() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func syncIconSwitchingMonitor() {
        IconSwitchingMonitor.shared.updateConfiguration(
            appURL: selectedAppURL,
            lightIcon: lightIcon,
            darkIcon: generatedDarkIcon ?? darkIcon,
            refreshesDockAutomatically: refreshesDockAutomatically
        )
        IconSwitchingMonitor.shared.setEnabled(keepsMonitoringInBackground && switchesIconWithSystemAppearance)
    }

    private func registerModifiedApp(_ url: URL) {
        guard let appURL = normalizedApplicationURL(from: url) else { return }

        let app = ModifiedApp(url: appURL)
        if let index = modifiedApps.firstIndex(where: { $0.id == app.id }) {
            modifiedApps[index] = app
        } else {
            modifiedApps.append(app)
            modifiedApps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    private func unregisterModifiedApp(_ url: URL) {
        let appURL = normalizedApplicationURL(from: url) ?? url
        modifiedApps.removeAll { $0.id == appURL.path(percentEncoded: false) }
    }
}

#Preview {
    ContentView()
}
