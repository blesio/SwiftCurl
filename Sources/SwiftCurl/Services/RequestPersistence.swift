import Foundation

struct RequestPersistence {
    private let fileManager = FileManager.default

    var storageURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "SwiftCurl", directoryHint: .isDirectory)
            .appending(path: "projects.json")
    }

    func load() throws -> StoredWorkspace {
        let url = storageURL
        guard fileManager.fileExists(atPath: url.path) else {
            return StoredWorkspace(projects: Self.sampleProjects, responses: [:])
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        if let workspace = try? decoder.decode(StoredWorkspace.self, from: data) {
            return workspace
        }

        let projects = try decoder.decode([RESTProject].self, from: data)
        return StoredWorkspace(projects: projects, responses: [:])
    }

    func save(projects: [RESTProject], responses: [UUID: ResponseRecord]) throws {
        let url = storageURL
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(StoredWorkspace(projects: projects, responses: responses))
        try data.write(to: url, options: [.atomic])
    }

    static var sampleProjects: [RESTProject] {
        [
            RESTProject(
                name: "Example Project",
                requests: [
                    RESTRequest(name: "HTTPBin GET")
                ]
            )
        ]
    }
}

struct StoredWorkspace: Codable {
    var projects: [RESTProject]
    var responses: [UUID: ResponseRecord]
}

struct ProjectArchive: Codable {
    var version = 1
    var project: RESTProject
    var responses: [UUID: ResponseRecord]
}
