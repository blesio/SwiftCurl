import SwiftUI

struct SidebarView: View {
    @Bindable var store: RequestStore
    @State private var collapsedProjectIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.projects) { project in
                    Section {
                        if !collapsedProjectIDs.contains(project.id) {
                            ForEach(project.requests) { request in
                                let selection = RequestSelection(projectID: project.id, requestID: request.id)

                                SidebarRequestRow(
                                    request: request,
                                    isSelected: store.selection == selection
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.selection = selection
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    } header: {
                        ProjectHeaderView(
                            nameBox: store.bindingForProjectName(projectID: project.id),
                            isCollapsed: collapsedProjectIDs.contains(project.id),
                            toggleCollapse: {
                                toggleProjectCollapse(project.id)
                            }
                        )
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Menu {
                    Button {
                        store.addProject()
                    } label: {
                        Label("New Project", systemImage: "folder.badge.plus")
                    }

                    Button {
                        store.importProjectArchive()
                    } label: {
                        Label("Import Project", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        store.exportSelectedProject()
                    } label: {
                        Label("Export Project", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.selectedProject == nil)

                    Divider()

                    Button(role: .destructive) {
                        store.deleteSelectedProject()
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                    .disabled(store.selectedProject == nil)
                } label: {
                    Label("Project", systemImage: "folder")
                }
                .menuStyle(.borderlessButton)

                Button {
                    store.deleteSelectedRequest()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(store.selectedRequest == nil)

                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }

    private func toggleProjectCollapse(_ projectID: UUID) {
        if collapsedProjectIDs.contains(projectID) {
            collapsedProjectIDs.remove(projectID)
        } else {
            collapsedProjectIDs.insert(projectID)
        }
    }
}

private struct ProjectHeaderView: View {
    let nameBox: BindingBox<String>
    let isCollapsed: Bool
    let toggleCollapse: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: toggleCollapse) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }
            .buttonStyle(.plain)

            TextField("Project", text: Binding(get: nameBox.get, set: nameBox.set))
                .textFieldStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct SidebarRequestRow: View {
    let request: RESTRequest
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(request.method.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? selectedMethodColor : methodColor)
                .frame(width: 46, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(request.url)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.68) : Color.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.14))
            }
        }
    }

    private var methodColor: Color {
        switch request.method {
        case .get: .green
        case .post: .blue
        case .put, .patch: .orange
        case .delete: .red
        case .head, .options: .secondary
        }
    }

    private var selectedMethodColor: Color {
        switch request.method {
        case .get: .green
        case .post: Color(red: 0.0, green: 0.35, blue: 0.85)
        case .put, .patch: .orange
        case .delete: .red
        case .head, .options: .secondary
        }
    }
}
