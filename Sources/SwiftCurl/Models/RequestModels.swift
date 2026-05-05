import Foundation

enum HTTPMethod: String, CaseIterable, Codable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    var id: String { rawValue }
}

enum AuthKind: String, CaseIterable, Codable, Identifiable {
    case none = "None"
    case basic = "Basic"
    case bearer = "Bearer"
    case apiKey = "API Key"

    var id: String { rawValue }
}

enum APIKeyLocation: String, CaseIterable, Codable, Identifiable {
    case header = "Header"
    case query = "Query"

    var id: String { rawValue }
}

enum BodyMode: String, CaseIterable, Codable, Identifiable {
    case raw = "Raw"
    case formURLEncoded = "x-www-form-urlencoded"

    var id: String { rawValue }
}

struct AuthConfig: Codable, Equatable {
    var kind: AuthKind = .none
    var username = ""
    var password = ""
    var token = ""
    var apiKeyName = ""
    var apiKeyValue = ""
    var apiKeyLocation: APIKeyLocation = .header
}

struct RequestSettings: Codable, Equatable {
    var allowsInvalidSSLCertificates = false
}

struct HeaderItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var value: String
    var isEnabled: Bool = true

    init(id: UUID = UUID(), name: String, value: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.value = value
        self.isEnabled = isEnabled
    }
}

struct RESTRequest: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var method: HTTPMethod = .get
    var url = "https://httpbin.org/get"
    var headers: [HeaderItem] = []
    var queryItems: [HeaderItem] = []
    var auth = AuthConfig()
    var settings = RequestSettings()
    var bodyMode: BodyMode = .raw
    var body = ""
    var urlEncodedBodyItems: [HeaderItem] = []
    var notes = ""

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case method
        case url
        case headers
        case queryItems
        case auth
        case settings
        case bodyMode
        case body
        case urlEncodedBodyItems
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        method = try container.decodeIfPresent(HTTPMethod.self, forKey: .method) ?? .get
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? "https://httpbin.org/get"
        headers = try container.decodeIfPresent([HeaderItem].self, forKey: .headers) ?? []
        queryItems = try container.decodeIfPresent([HeaderItem].self, forKey: .queryItems) ?? []
        auth = try container.decodeIfPresent(AuthConfig.self, forKey: .auth) ?? AuthConfig()
        settings = try container.decodeIfPresent(RequestSettings.self, forKey: .settings) ?? RequestSettings()
        bodyMode = try container.decodeIfPresent(BodyMode.self, forKey: .bodyMode) ?? .raw
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        urlEncodedBodyItems = try container.decodeIfPresent([HeaderItem].self, forKey: .urlEncodedBodyItems) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

struct RESTProject: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var requests: [RESTRequest]

    init(id: UUID = UUID(), name: String, requests: [RESTRequest] = []) {
        self.id = id
        self.name = name
        self.requests = requests
    }
}

struct ResponseRecord: Codable, Equatable {
    var id = UUID()
    var statusCode: Int?
    var duration: TimeInterval
    var headers: [String: String]
    var body: String
    var bodyByteCount: Int
    var bodyData: Data
    var contentType: String?
    var errorMessage: String?

    init(
        statusCode: Int?,
        duration: TimeInterval,
        headers: [String: String],
        body: String,
        bodyByteCount: Int,
        bodyData: Data,
        contentType: String?,
        errorMessage: String?
    ) {
        self.statusCode = statusCode
        self.duration = duration
        self.headers = headers
        self.body = body
        self.bodyByteCount = bodyByteCount
        self.bodyData = bodyData
        self.contentType = contentType
        self.errorMessage = errorMessage
    }

    enum CodingKeys: String, CodingKey {
        case id
        case statusCode
        case duration
        case headers
        case body
        case bodyByteCount
        case bodyData
        case contentType
        case errorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        bodyByteCount = try container.decodeIfPresent(Int.self, forKey: .bodyByteCount) ?? body.utf8.count
        bodyData = try container.decodeIfPresent(Data.self, forKey: .bodyData) ?? Data(body.utf8)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }

    var isAudio: Bool {
        let lowercasedType = contentType?.lowercased() ?? ""
        return lowercasedType.contains("audio/mpeg")
            || lowercasedType.contains("audio/mp3")
            || lowercasedType.contains("audio/wav")
            || lowercasedType.contains("audio/x-wav")
            || lowercasedType.contains("audio/wave")
            || bodyData.starts(with: [0x49, 0x44, 0x33])
            || bodyData.starts(with: [0xFF, 0xFB])
            || bodyData.starts(with: [0x52, 0x49, 0x46, 0x46])
    }

    var suggestedFileExtension: String {
        let lowercasedType = contentType?.lowercased() ?? ""
        if lowercasedType.contains("wav") || bodyData.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            return "wav"
        }
        if lowercasedType.contains("mpeg") || lowercasedType.contains("mp3") || bodyData.starts(with: [0x49, 0x44, 0x33]) || bodyData.starts(with: [0xFF, 0xFB]) {
            return "mp3"
        }
        if lowercasedType.contains("json") {
            return "json"
        }
        if lowercasedType.hasPrefix("text/") {
            return "txt"
        }
        return "bin"
    }
}

struct RequestSelection: Hashable {
    var projectID: UUID
    var requestID: UUID
}
