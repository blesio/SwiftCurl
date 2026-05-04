import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class RequestStore {
    var projects: [RESTProject] = []
    var selection: RequestSelection?
    var responses: [UUID: ResponseRecord] = [:]
    var sendingRequestIDs: Set<UUID> = []
    var statusMessage = ""
    var curlImportText = ""
    var curlExportText = ""

    private let persistence = RequestPersistence()
    private let networkClient = NetworkClient()

    init() {
        load()
    }

    var selectedProjectID: UUID? {
        get { selection?.projectID ?? projects.first?.id }
        set {
            guard let id = newValue,
                  let project = projects.first(where: { $0.id == id }) else { return }
            selection = project.requests.first.map { RequestSelection(projectID: id, requestID: $0.id) }
        }
    }

    var selectedRequest: RESTRequest? {
        guard let location = selectedLocation else { return nil }
        return projects[location.project].requests[location.request]
    }

    var selectedProject: RESTProject? {
        guard let projectID = selection?.projectID ?? projects.first?.id else { return nil }
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
        guard let location = selectedLocation else { return nil }
        return BindingBox(
            get: { self.projects[location.project].requests[location.request] },
            set: { newValue in
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

    func load() {
        do {
            let workspace = try persistence.load()
            projects = workspace.projects
            responses = workspace.responses
            if let project = projects.first, let request = project.requests.first {
                selection = RequestSelection(projectID: project.id, requestID: request.id)
            }
            statusMessage = "Ready"
        } catch {
            projects = RequestPersistence.sampleProjects
            statusMessage = "Could not load saved projects: \(error.localizedDescription)"
        }
    }

    func save() {
        do {
            try persistence.save(projects: projects, responses: responses)
            statusMessage = "Saved"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func addProject() {
        let project = RESTProject(name: "New Project", requests: [RESTRequest(name: "New Request")])
        projects.append(project)
        selection = RequestSelection(projectID: project.id, requestID: project.requests[0].id)
        save()
    }

    func addRequest() {
        guard !projects.isEmpty else {
            addProject()
            return
        }

        let projectID = selection?.projectID ?? projects[0].id
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let request = RESTRequest(name: "New Request")
        projects[projectIndex].requests.append(request)
        selection = RequestSelection(projectID: projects[projectIndex].id, requestID: request.id)
        save()
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

        if projects.indices.contains(projectIndex), let nextRequest = projects[projectIndex].requests.first {
            selection = RequestSelection(projectID: projects[projectIndex].id, requestID: nextRequest.id)
        } else if let previousProject = projects.prefix(projectIndex).last, let previousRequest = previousProject.requests.first {
            selection = RequestSelection(projectID: previousProject.id, requestID: previousRequest.id)
        } else if let firstProject = projects.first, let firstRequest = firstProject.requests.first {
            selection = RequestSelection(projectID: firstProject.id, requestID: firstRequest.id)
        } else {
            selection = nil
        }

        statusMessage = "Project deleted"
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

    func deleteSelectedRequest() {
        guard let location = selectedLocation else { return }
        let requestID = projects[location.project].requests[location.request].id
        projects[location.project].requests.remove(at: location.request)
        responses[requestID] = nil
        sendingRequestIDs.remove(requestID)
        if let next = projects[location.project].requests.first {
            selection = RequestSelection(projectID: projects[location.project].id, requestID: next.id)
        } else {
            selection = nil
        }
        save()
    }

    func importCurlIntoSelectedProject() {
        guard let imported = CurlCodec.parse(curlImportText) else {
            statusMessage = "Could not parse cURL command"
            return
        }

        guard !projects.isEmpty else {
            projects = [RESTProject(name: "Imported", requests: [imported])]
            selection = RequestSelection(projectID: projects[0].id, requestID: imported.id)
            save()
            return
        }

        let projectID = selection?.projectID ?? projects[0].id
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[projectIndex].requests.append(imported)
        selection = RequestSelection(projectID: projects[projectIndex].id, requestID: imported.id)
        curlImportText = ""
        save()
    }

    func refreshCurlExport() {
        curlExportText = selectedRequest.map(CurlCodec.makeCurl) ?? ""
    }

    func formatSelectedJSONBody() {
        guard let location = selectedLocation else { return }
        let body = projects[location.project].requests[location.request].body
        guard let formatted = CurlCodec.prettyPrintedJSON(body) else {
            statusMessage = "Body is not valid JSON"
            return
        }
        projects[location.project].requests[location.request].body = formatted
        save()
    }

    func sendSelectedRequest() async {
        guard let request = selectedRequest else { return }
        let requestID = request.id
        sendingRequestIDs.insert(requestID)
        responses[requestID] = nil
        statusMessage = "Sending..."
        let response = await networkClient.send(request)
        responses[requestID] = response
        sendingRequestIDs.remove(requestID)
        statusMessage = response.errorMessage == nil ? "Request complete" : "Request failed"
        save()
    }

    private var selectedLocation: (project: Int, request: Int)? {
        guard let selection else { return nil }
        guard let projectIndex = projects.firstIndex(where: { $0.id == selection.projectID }),
              let requestIndex = projects[projectIndex].requests.firstIndex(where: { $0.id == selection.requestID }) else {
            return nil
        }
        return (projectIndex, requestIndex)
    }

    private func appendImportedProject(_ archive: ProjectArchive) {
        var project = archive.project
        let oldProjectID = project.id
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

        if let firstRequest = project.requests.first {
            selection = RequestSelection(projectID: project.id, requestID: firstRequest.id)
        } else {
            selection = nil
        }

        statusMessage = "Imported \(archive.project.name)"
        save()

        _ = oldProjectID
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
