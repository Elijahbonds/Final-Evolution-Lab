import SwiftUI

struct NexusStudioIDEView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var workspace = NexusStudioWorkspaceService.shared
    @State private var fileTree: [NexusStudioFileNode] = []
    @State private var recentFiles: [NexusStudioRecentFile] = []
    @State private var openFile: NexusStudioOpenFile?
    @State private var editorText: String = ""
    @State private var isDirty = false
    @State private var accessMode: NexusStudioAccessMode = .readOnly
    @State private var isLoadingFile = false
    @State private var statusMessage: String?
    @State private var showPaths = false
    @State private var showSaveConfirm = false
    @State private var selectedPanel: NexusStudioPanel = .editor
    @State private var runPanelModeId: GameModeId?
    @State private var runPanelReadiness: Double = 75
    @State private var runPanelGeneratedPath: String?
    @State private var rootFilter: NexusStudioRootFilter = .all
    @State private var searchQuery: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            detailPane
        }
        .navigationTitle("NEXUS Studio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { toolbarItems }
        .background(Theme.deepBlack)
        .onAppear {
            workspace.bootstrap()
            applyPendingLaunchContext()
            refreshTree()
            focusDetailPaneIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nexusStudioOpen)) { _ in
            applyPendingLaunchContext()
            focusDetailPaneIfNeeded()
        }
        .onChange(of: rootFilter) { _, _ in refreshTree() }
        .onChange(of: searchQuery) { _, _ in refreshTree() }
        .onChange(of: selectedPanel) { _, _ in focusDetailPaneIfNeeded() }
        .alert("NEXUS Studio paths", isPresented: $showPaths) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pathInfo)
        }
        .confirmationDialog(
            "Save draft?",
            isPresented: $showSaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Save draft") {
                Task { await saveCurrentFile() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let openFile {
                Text("Keeps a local copy in your private sandbox.\n\n\(openFile.relativePath)")
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            headerBanner
            NexusStudioFileTreeView(
                roots: fileTree,
                recentFiles: recentFiles,
                selectedPath: openFile?.relativePath,
                rootFilter: $rootFilter,
                searchQuery: $searchQuery,
                onSelect: { path in
                    Task { await open(path: path) }
                }
            )
        }
        .background(Theme.deepBlack)
    }

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FELPreviewLabel(text: FELPremiumCopy.Preview.ideV03)
                Spacer()
            }

            Text("Explore source files and draft changes locally. Edits stay in a private sandbox — your live project is never modified.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Panel", selection: $selectedPanel) {
                ForEach(NexusStudioPanel.allCases) { panel in
                    Label(panel.label, systemImage: panel.icon).tag(panel)
                }
            }
            .pickerStyle(.segmented)

            if selectedPanel == .editor {
                Picker("Access", selection: $accessMode) {
                    ForEach(NexusStudioAccessMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: accessMode) { _, newMode in
                    if newMode == .readOnly, isDirty {
                        statusMessage = "Switched to read-only. Unsaved sandbox edits kept in memory."
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.slateCard)
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selectedPanel {
        case .editor:
            editorPane
        case .run:
            NexusStudioRunPanelView(
                initialModeId: runPanelModeId,
                initialReadiness: runPanelReadiness,
                initialGeneratedPath: runPanelGeneratedPath
            )
        case .aiStudio:
            NexusAIStudioSettingsView()
        }
    }

    @ViewBuilder
    private var editorPane: some View {
        if let openFile {
            VStack(spacing: 0) {
                fileHeader(openFile)
                if isLoadingFile {
                    ProgressView("Loading…")
                        .tint(Theme.brandCyan)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    NexusStudioCodeEditorView(
                        content: editorText,
                        language: NexusStudioLanguage.from(path: openFile.relativePath),
                        isReadOnly: accessMode == .readOnly,
                        onContentChange: { newText in
                            guard accessMode == .sandboxEdit else { return }
                            editorText = newText
                            isDirty = true
                        }
                    )
                }
                footerBar
            }
            .background(Theme.deepBlack)
        } else {
            studioEmptyState
        }
    }

    private var studioEmptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ContentUnavailableView(
                    "NEXUS Studio",
                    systemImage: "hammer.fill",
                    description: Text("Browse project sources and draft local edits. Your live project stays untouched.")
                )

                VStack(alignment: .leading, spacing: 10) {
                    NexusStudioSectionTitle(title: "Quick start")

                    studioQuickStartRow(
                        icon: "wand.and.stars",
                        title: "Game Generator",
                        detail: "Arena → Create tab — describe a mode, export spec JSON to sandbox.",
                        action: { openRunPanelFromQuickStart() }
                    )
                    studioQuickStartRow(
                        icon: "play.rectangle.on.rectangle",
                        title: "Play on device",
                        detail: "Launch generated games or quick-play modes on this device.",
                        action: { openRunPanelFromQuickStart() }
                    )
                    studioQuickStartRow(
                        icon: "doc.text",
                        title: "Game specs",
                        detail: "Open exported game files from the file tree after creating a mode.",
                        action: nil
                    )
                }
                .nexusStudioCard()
            }
            .padding(16)
        }
        .background(Theme.deepBlack)
    }

    @ViewBuilder
    private func studioQuickStartRow(
        icon: String,
        title: String,
        detail: String,
        action: (() -> Void)?
    ) -> some View {
        let content = HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.brandCyan)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }

        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.bordered)
        } else {
            content
        }
    }

    private func fileHeader(_ file: NexusStudioOpenFile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(Theme.brandCyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(file.relativePath)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Text(NexusStudioLanguage.from(path: file.relativePath).displayLabel)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.brandCyan.opacity(0.12)))
            if isDirty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("UNSAVED")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
            Text(file.source.rawValue.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.neonGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.slateCard)
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            if let statusMessage {
                NexusStudioStatusPill(message: statusMessage, isError: statusMessage.localizedCaseInsensitiveContains("fail"))
            }
            Spacer()
            if accessMode == .sandboxEdit, openFile != nil {
                Button("Save draft") {
                    showSaveConfirm = true
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isDirty ? Theme.neonGreen : Theme.neonGreen.opacity(0.35))
                .clipShape(Capsule())
                .disabled(!isDirty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.slateCard.opacity(0.9))
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Close") { dismiss() }
                .foregroundStyle(Theme.brandCyan)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Copy repo path") {
                    NEXUSCursorBridge.copyRepoRootToPasteboard()
                    statusMessage = "Repo path copied."
                }
                Button("Open repo in Cursor") {
                    NEXUSCursorBridge.copyRepoRootToPasteboard()
                    NEXUSCursorBridge.openCursorRepoURL()
                    statusMessage = "Opened Cursor repo URI."
                }
                if let openFile {
                    Button("Open file in Cursor") {
                        let repoRoot = workspace.repoPathLabel()
                        let fullPath = (repoRoot as NSString).appendingPathComponent(openFile.relativePath)
                        NEXUSCursorBridge.copyTextToPasteboard(fullPath)
                        NEXUSCursorBridge.openCursorFileURL(absolutePath: fullPath)
                        statusMessage = "Opened file in Cursor."
                    }
                }
            } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showPaths.toggle()
            } label: {
                Image(systemName: "info.circle")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                workspace.bootstrap()
                refreshTree()
                statusMessage = "File tree refreshed."
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    private func refreshTree() {
        fileTree = workspace.buildFileTree(filter: rootFilter, searchQuery: searchQuery)
        recentFiles = workspace.recentFiles()
    }

    private func applyPendingLaunchContext() {
        guard let ctx = NexusStudioCoordinator.shared.consumePendingLaunch() else { return }
        selectedPanel = ctx.panel
        runPanelModeId = ctx.modeId
        runPanelReadiness = ctx.readiness
        runPanelGeneratedPath = ctx.sandboxRelativePath
        focusDetailPaneIfNeeded()

        if let path = ctx.sandboxRelativePath, ctx.panel == .editor {
            Task { await open(path: path, focusEditor: true) }
        }
    }

    private func openRunPanelFromQuickStart() {
        selectedPanel = .run
        focusDetailPaneIfNeeded()
    }

    /// On iPhone-width simulators the split view defaults to the sidebar — surface Run/editor detail after onboarding taps.
    private func focusDetailPaneIfNeeded() {
        guard horizontalSizeClass == .compact else { return }
        columnVisibility = .detailOnly
    }

    private func open(path: String, focusEditor: Bool = true) async {
        isLoadingFile = true
        statusMessage = nil
        defer { isLoadingFile = false }
        do {
            let loaded = try workspace.loadFile(relativePath: path)
            openFile = loaded
            editorText = loaded.content
            isDirty = false
            workspace.recordRecentFile(relativePath: path)
            recentFiles = workspace.recentFiles()
            if focusEditor {
                selectedPanel = .editor
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveCurrentFile() async {
        guard let file = openFile, accessMode == .sandboxEdit else { return }
        do {
            try workspace.saveToSandbox(relativePath: file.relativePath, content: editorText)
            openFile = NexusStudioOpenFile(
                relativePath: file.relativePath,
                content: editorText,
                isDirty: false,
                source: .sandbox
            )
            isDirty = false
            statusMessage = "Saved to sandbox."
            NexusStudioHotReloadStub.notifySandboxSave(relativePath: file.relativePath)
            FelToastCenter.shared.show("Sandbox save OK", isError: false)
        } catch {
            statusMessage = error.localizedDescription
            FelToastCenter.shared.show(error.localizedDescription, isError: true)
        }
    }
}

extension NexusStudioIDEView {
    var pathInfo: String {
        """
        Repo: \(workspace.repoPathLabel())
        Sandbox: \(workspace.sandboxPathLabel())
        Cursor: \(NEXUSCursorBridge.cursorRepoURI())
        Playtest: \(NexusPlaytestArtifactReader.relativePath)
        """
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NexusStudioIDEView()
    }
    .preferredColorScheme(.dark)
}
#endif
