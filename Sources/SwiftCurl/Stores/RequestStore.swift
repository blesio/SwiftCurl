import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class RequestStore {
    var projects: [RESTProject] = []
    var selection: RequestSelection?
    var focusedProjectID: UUID?
    var responses: [UUID: ResponseRecord] = [:]
    var sendingRequestIDs: Set<UUID> = []
    var statusMessage = ""
    var curlImportText = ""
    var curlExportText = ""

    private let persistence = RequestPersistence()
    private let networkClient = NetworkClient()
    private var saveTask: Task<Void, Never>?

    init() {
        load()
    }

    var selectedProjectID: UUID? {
        get { selection?.projectID ?? focusedProjectID ?? projects.first?.id }
        set {
            guard let id = newValue,
                  let project = projects.first(where: { $0.id == id }) else { return }
            focusedProjectID = id
            selection = project.requests.first.map { RequestSelection(projectID: id, requestID: $0.id) }
        }
    }

    var selectedRequest: RESTRequest? {
        guard let location = selectedLocation else { return nil }
        return projects[location.project].requests[location.request]
    }

    var selectedProject: RESTProject? {
        guard let projectID = selectedProjectID else { return nil }
        return projects.first { $0.id == projectID }
    }

    var selectedResponse: ResponseRecord? {
        guard let requestID = selection?.requestID else { return nil }
        return responses[requestID]
    }

    var isSelectedRequestSending: Bool {
        guard let requestID = selection?.requestID else { return false }
        return sendingRequestIDs.contains(requestID)
    }

    func bindingForSelectedRequest() -> BindingBox<RESTRequest>? {
        guard let selection else { return nil }
        let projectID = selection.projectID
        let requestID = selection.requestID

        return BindingBox(
            get: {
                guard let location = self.location(projectID: projectID, requestID: requestID) else {
                    return RESTRequest(name: "")
                }
                return self.projects[location.project].requests[location.request]
            },
            set: { newValue in
                guard let location = self.location(projectID: projectID, requestID: requestID) else {
                    return
                }
                self.projects[location.project].requests[location.request] = newValue
                self.save()
            }
        )
    }

    func bindingForProjectName(projectID: UUID) -> BindingBox<String> {
        BindingBox(
            get: {
                self.projects.first { $0.id == projectID }?.name ?? ""
            },
            set: { newValue in
                guard let index = self.projects.firstIndex(where: { $0.id == projectID }) else { return }
                self.projects[index].name = newValue
                self.save()
            }
        )
    }

    func bindingForSelectedProjectVariables() -> BindingBox<[HeaderItem]>? {
        guard let projectID = selectedProjectID else { return nil }
        return BindingBox(
            get: { self.projects.first { $0.id == projectID }?.variables ?? [] },
            set: { newValue in
                guard let index = self.projects.firstIndex(where: { $0.id == projectID }) else { return }
                self.projects[index].variables = newValue
                self.save()
            }
        )
    }

    func load() {
        do {
            let workspace = try persistence.load()
            projects = workspace.projects
            responses = workspace.responses
            if let project = projects.first, let request = project.requests.first {
                focusedProjectID = project.id
                selection = RequestSelection(projectID: project.id, requestID: request.id)
            } else if let project = projects.first {
                focusedProjectID = project.id
                selection = nil
            }
            statusMessage = "Ready"
        } catch {
            projects = RequestPersistence.sampleProjects
            if let project = projects.first, let request = project.requests.first {
                focusedProjectID = project.id
                selection = RequestSelection(projectID: project.id, requestID: request.id)
            }
            statusMessage = "Could not load saved projects: \(error.localizedDescription)"
        }
    }

    func save() {
        let projectsSnapshot = projects
        let responsesSnapshot = responses
        let storageURL = persistence.storageURL

        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(450))
            } catch {
                return
            }

            let result = await Self.persist(
                projects: projectsSnapshot,
                responses: responsesSnapshot,
                storageURL: storageURL
            )

            guard !Task.isCancelled else { return }
            switch result {
            case .success:
                statusMessage = "Saved"
            case .failure(let error):
                statusMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    private nonisolated static func persist(
        projects: [RESTProject],
        responses: [UUID: ResponseRecord],
        storageURL: URL
    ) async -> Result<Void, Error> {
        await Task.detached(priority: .utility) {
            do {
                try RequestPersistence.save(projects: projects, responses: responses, to: storageURL)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value
    }

    func addProject() {
        let project = RESTProject(name: "New Project", requests: [RESTRequest(name: "New Request")])
        projects.append(project)
        focusedProjectID = project.id
        selection = RequestSelection(projectID: project.id, requestID: project.requests[0].id)
        save()
    }

    func addRequest() {
        guard !projects.isEmpty else {
            addProject()
            return
        }

        let projectID = selectedProjectID ?? projects[0].id
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let request = RESTRequest(name: "New Request")
        projects[projectIndex].requests.append(request)
        focusedProjectID = projects[projectIndex].id
        selection = RequestSelection(projectID: projects[projectIndex].id, requestID: request.id)
        save()
    }

    func focusProject(_ projectID: UUID) {
        guard projects.contains(where: { $0.id == projectID }) else { return }
        focusedProjectID = projectID
        selection = nil
    }

    func selectRequest(_ selection: RequestSelection) {
        focusedProjectID = selection.projectID
        self.selection = selection
    }

    func deleteSelectedProject() {
        guard let projectID = selectedProject?.id,
              let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else {
            statusMessage = "No project selected"
            return
        }

        let requestIDs = Set(projects[projectIndex].requests.map(\.id))
        projects.remove(at: projectIndex)

        for requestID in requestIDs {
            responses[requestID] = nil
            sendingRequestIDs.remove(requestID)
        }

        focusAfterDeletingProject(at: projectIndex)
        statusMessage = "Project deleted"
        save()
    }

    func deleteSelectedRequest() {
        guard let location = selectedLocation else { return }
        let projectID = projects[location.project].id
        let requestID = projects[location.project].requests[location.request].id

        projects[location.project].requests.remove(at: location.request)
        responses[requestID] = nil
        sendingRequestIDs.remove(requestID)
        focusedProjectID = projectID

        if let next = projects[location.project].requests.first {
            selection = RequestSelection(projectID: projectID, requestID: next.id)
        } else {
            selection = nil
        }

        save()
    }

    func duplicateSelectedRequest() {
        guard let selection else { return }
        duplicateRequest(projectID: selection.projectID, requestID: selection.requestID)
    }

    func duplicateRequest(projectID: UUID, requestID: UUID) {
        guard let location = location(projectID: projectID, requestID: requestID) else { return }

        let original = projects[location.project].requests[location.request]
        var duplicate = original
        duplicate.id = UUID()
        duplicate.name = uniqueRequestName(original.name, in: projects[location.project])

        let insertIndex = location.request + 1
        projects[location.project].requests.insert(duplicate, at: insertIndex)

        if let response = responses[original.id] {
            responses[duplicate.id] = response
        }

        focusedProjectID = projectID
        selection = RequestSelection(projectID: projectID, requestID: duplicate.id)
        save()
    }

    func moveRequests(projectID: UUID, from source: IndexSet, to destination: Int) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }

        projects[projectIndex].requests.move(fromOffsets: source, toOffset: destination)
        focusedProjectID = projectID
        save()
    }

    func moveRequest(requestID: UUID, toProjectID destinationProjectID: UUID, before targetRequestID: UUID?) {
        guard requestID != targetRequestID,
              let sourceProjectIndex = projects.firstIndex(where: { project in
                  project.requests.contains { $0.id == requestID }
              }),
              let sourceRequestIndex = projects[sourceProjectIndex].requests.firstIndex(where: { $0.id == requestID }),
              projects.contains(where: { $0.id == destinationProjectID }) else {
            return
        }

        let request = projects[sourceProjectIndex].requests.remove(at: sourceRequestIndex)

        guard let destinationProjectIndex = projects.firstIndex(where: { $0.id == destinationProjectID }) else {
            projects[sourceProjectIndex].requests.insert(request, at: sourceRequestIndex)
            return
        }

        let insertionIndex: Int
        if let targetRequestID,
           let targetIndex = projects[destinationProjectIndex].requests.firstIndex(where: { $0.id == targetRequestID }) {
            insertionIndex = targetIndex
        } else {
            insertionIndex = projects[destinationProjectIndex].requests.endIndex
        }

        projects[destinationProjectIndex].requests.insert(request, at: insertionIndex)
        focusedProjectID = destinationProjectID
        selection = RequestSelection(projectID: destinationProjectID, requestID: request.id)
        save()
    }

    func exportSelectedProject() {
        guard let project = selectedProject else {
            statusMessage = "No project selected"
            return
        }

        let requestIDs = Set(project.requests.map(\.id))
        let archive = ProjectArchive(
            project: project,
            responses: responses.filter { requestIDs.contains($0.key) }
        )

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(safeFileName(project.name)).swiftcurlproject"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(archive)
                try data.write(to: url, options: [.atomic])
                Task { @MainActor in self?.statusMessage = "Project exported" }
            } catch {
                Task { @MainActor in
                    self?.statusMessage = "Export failed: \(error.localizedDescription)"
                    NSAlert(error: error).runModal()
                }
            }
        }
    }

    func importProjectArchive() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]

        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }

            do {
                let data = try Data(contentsOf: url)
                let archive = try JSONDecoder().decode(ProjectArchive.self, from: data)
                Task { @MainActor in
                    self?.appendImportedProject(archive)
                }
            } catch {
                Task { @MainActor in
                    self?.statusMessage = "Import failed: \(error.localizedDescription)"
                    NSAlert(error: error).runModal()
                }
            }
        }
    }

    func importCurlIntoSelectedProject() {
        guard let imported = CurlCodec.parse(curlImportText) else {
            statusMessage = "Could not parse cURL command"
            return
        }

        guard !projects.isEmpty else {
            projects = [RESTProject(name: "Imported", requests: [imported])]
            focusedProjectID = projects[0].id
            selection = RequestSelection(projectID: projects[0].id, requestID: imported.id)
            save()
            return
        }

        let projectID = selectedProjectID ?? projects[0].id
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[projectIndex].requests.append(imported)
        focusedProjectID = projects[projectIndex].id
        selection = RequestSelection(projectID: projects[projectIndex].id, requestID: imported.id)
        curlImportText = ""
        save()
    }

    func refreshCurlExport() {
        curlExportText = selectedRequest.map(CurlCodec.makeCurl) ?? ""
    }

    func formatSelectedJSONBody() {
        guard let location = selectedLocation else { return }
        guard projects[location.project].requests[location.request].bodyMode == .raw else { return }
        let body = projects[location.project].requests[location.request].body
        guard let formatted = CurlCodec.prettyPrintedJSON(body) else {
            statusMessage = "Body is not valid JSON"
            return
        }
        projects[location.project].requests[location.request].body = formatted
        save()
    }

    func sendSelectedRequest() async {
        guard let request = selectedRequest,
              let projectIndex = projects.firstIndex(where: { $0.requests.contains { $0.id == request.id } }) else { return }
        let requestID = request.id
        let resolvedRequest = ProjectVariables.resolving(request, with: projects[projectIndex].variables)
        sendingRequestIDs.insert(requestID)
        responses[requestID] = nil
        statusMessage = "Sending..."
        let response = await networkClient.send(resolvedRequest)
        responses[requestID] = response
        let captured = ProjectVariables.capturedValues(from: response, rules: request.variableCaptures)
        for (name, value) in captured {
            if let index = projects[projectIndex].variables.firstIndex(where: { $0.name == name }) {
                projects[projectIndex].variables[index].value = value
            } else {
                projects[projectIndex].variables.append(HeaderItem(name: name, value: value))
            }
        }
        sendingRequestIDs.remove(requestID)
        if response.errorMessage != nil {
            statusMessage = "Request failed"
        } else if captured.isEmpty {
            statusMessage = "Request complete"
        } else {
            statusMessage = "Request complete · updated \(captured.count) variable\(captured.count == 1 ? "" : "s")"
        }
        save()
    }

    private var selectedLocation: (project: Int, request: Int)? {
        guard let selection else { return nil }
        return location(projectID: selection.projectID, requestID: selection.requestID)
    }

    private func location(projectID: UUID, requestID: UUID) -> (project: Int, request: Int)? {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let requestIndex = projects[projectIndex].requests.firstIndex(where: { $0.id == requestID }) else {
            return nil
        }

        return (projectIndex, requestIndex)
    }

    private func focusAfterDeletingProject(at deletedIndex: Int) {
        if projects.indices.contains(deletedIndex) {
            focusProjectAfterMutation(projects[deletedIndex])
        } else if let previousProject = projects.prefix(deletedIndex).last {
            focusProjectAfterMutation(previousProject)
        } else if let firstProject = projects.first {
            focusProjectAfterMutation(firstProject)
        } else {
            focusedProjectID = nil
            selection = nil
        }
    }

    private func focusProjectAfterMutation(_ project: RESTProject) {
        focusedProjectID = project.id
        selection = project.requests.first.map {
            RequestSelection(projectID: project.id, requestID: $0.id)
        }
    }

    private func appendImportedProject(_ archive: ProjectArchive) {
        var project = archive.project
        project.id = UUID()
        project.name = uniqueProjectName(project.name)

        var remappedResponses: [UUID: ResponseRecord] = [:]
        for index in project.requests.indices {
            let oldRequestID = project.requests[index].id
            let newRequestID = UUID()
            project.requests[index].id = newRequestID
            if let response = archive.responses[oldRequestID] {
                remappedResponses[newRequestID] = response
            }
        }

        projects.append(project)
        responses.merge(remappedResponses) { _, imported in imported }
        focusedProjectID = project.id

        if let firstRequest = project.requests.first {
            selection = RequestSelection(projectID: project.id, requestID: firstRequest.id)
        } else {
            selection = nil
        }

        statusMessage = "Imported \(archive.project.name)"
        save()
    }

    private func uniqueProjectName(_ name: String) -> String {
        let baseName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Imported Project" : name
        let existingNames = Set(projects.map(\.name))
        guard existingNames.contains(baseName) else { return baseName }

        var counter = 2
        while existingNames.contains("\(baseName) \(counter)") {
            counter += 1
        }
        return "\(baseName) \(counter)"
    }

    private func uniqueRequestName(_ name: String, in project: RESTProject) -> String {
        let baseName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Request" : name
        let copyName = "\(baseName) Copy"
        let existingNames = Set(project.requests.map(\.name))
        guard existingNames.contains(copyName) else { return copyName }

        var counter = 2
        while existingNames.contains("\(copyName) \(counter)") {
            counter += 1
        }
        return "\(copyName) \(counter)"
    }

    private func safeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "-")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Project" : cleaned
    }
}

struct BindingBox<Value> {
    var get: () -> Value
    var set: (Value) -> Void
}
