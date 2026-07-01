import SwiftUI

struct NexusStudioFileTreeView: View {
    let roots: [NexusStudioFileNode]
    let recentFiles: [NexusStudioRecentFile]
    let selectedPath: String?
    @Binding var rootFilter: NexusStudioRootFilter
    @Binding var searchQuery: String
    let onSelect: (String) -> Void

    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            searchBar

            List {
                if !recentFiles.isEmpty, searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        ForEach(recentFiles) { recent in
                            fileRow(recent.relativePath, label: recent.fileName)
                        }
                    } header: {
                        Text("RECENT")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Theme.slateCard)
                }

                if roots.isEmpty {
                    ContentUnavailableView(
                        searchQuery.isEmpty ? "No sources indexed" : "No matches",
                        systemImage: searchQuery.isEmpty ? "folder.badge.questionmark" : "magnifyingglass",
                        description: Text(searchQuery.isEmpty
                            ? "Set FEL_NEXUS_REPO_ROOT to your NEXUS checkout."
                            : "Try a different filter or search term.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(roots) { root in
                        NexusStudioTreeNodeView(
                            node: root,
                            depth: 0,
                            selectedPath: selectedPath,
                            expanded: $expanded,
                            onSelect: onSelect
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.deepBlack)
        .onAppear {
            expanded = Set(roots.map(\.id))
        }
        .onChange(of: roots.map(\.id)) { _, ids in
            expanded.formUnion(ids)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(NexusStudioRootFilter.allCases) { filter in
                    Button {
                        rootFilter = filter
                    } label: {
                        Text(filter.label)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(rootFilter == filter ? .black : Theme.brandCyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(rootFilter == filter ? Theme.brandCyan : Theme.brandCyan.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.slateCard.opacity(0.6))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Filter files…", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.slateCard)
    }

    private func fileRow(_ path: String, label: String) -> some View {
        Button {
            onSelect(path)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.neonGreen)
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(selectedPath == path ? Theme.brandCyan : .white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(selectedPath == path ? Theme.brandBlue.opacity(0.12) : Theme.slateCard)
    }
}

private struct NexusStudioTreeNodeView: View {
    let node: NexusStudioFileNode
    let depth: Int
    let selectedPath: String?
    @Binding var expanded: Set<String>
    let onSelect: (String) -> Void

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expanded.contains(node.id) },
                    set: { isOpen in
                        if isOpen { expanded.insert(node.id) } else { expanded.remove(node.id) }
                    }
                )
            ) {
                ForEach(node.children) { child in
                    NexusStudioTreeNodeView(
                        node: child,
                        depth: depth + 1,
                        selectedPath: selectedPath,
                        expanded: $expanded,
                        onSelect: onSelect
                    )
                }
            } label: {
                nodeLabel
            }
            .listRowBackground(Theme.slateCard)
        } else {
            Button {
                onSelect(node.relativePath)
            } label: {
                nodeLabel
            }
            .buttonStyle(.plain)
            .listRowBackground(selectedPath == node.relativePath ? Theme.brandBlue.opacity(0.12) : Theme.slateCard)
        }
    }

    private var nodeLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: node.isDirectory ? "folder.fill" : fileIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(node.isDirectory ? Theme.brandCyan : Theme.neonGreen)
                .frame(width: 16)

            Text(node.name)
                .font(.system(size: 12, weight: node.isDirectory ? .bold : .medium, design: .monospaced))
                .foregroundStyle(selectedPath == node.relativePath ? Theme.brandCyan : .white)
                .lineLimit(1)

            if !node.isDirectory {
                Text(node.language.displayLabel)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(depth) * 10)
        .padding(.vertical, 2)
    }

    private var fileIcon: String {
        switch node.language {
        case .cpp: "chevron.left.forwardslash.chevron.right"
        case .swift: "swift"
        case .json: "curlybraces"
        case .markdown: "doc.richtext"
        case .plain: "doc.text"
        }
    }
}
