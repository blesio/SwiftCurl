import Foundation

struct NetworkClient {
    private let prettyPrintLimit = 16 * 1024 * 1024

    func send(_ request: RESTRequest) async -> ResponseRecord {
        let startedAt = Date()

        do {
            let urlRequest = try makeURLRequest(from: request)
            let session = makeSession(for: request)
            let (data, response) = try await session.data(for: urlRequest)
            let duration = Date().timeIntervalSince(startedAt)
            let httpResponse = response as? HTTPURLResponse
            let headers = httpResponse?.allHeaderFields.reduce(into: [String: String]()) { partial, item in
                partial[String(describing: item.key)] = String(describing: item.value)
            } ?? [:]
            let contentType = headers.first { key, _ in
                key.caseInsensitiveCompare("Content-Type") == .orderedSame
            }?.value

            return ResponseRecord(
                statusCode: httpResponse?.statusCode,
                duration: duration,
                headers: headers,
                body: makeDisplayBody(data: data, contentType: contentType),
                bodyByteCount: data.count,
                bodyData: data,
                contentType: contentType,
                errorMessage: nil
            )
        } catch {
            return ResponseRecord(
                statusCode: nil,
                duration: Date().timeIntervalSince(startedAt),
                headers: [:],
                body: "",
                bodyByteCount: 0,
                bodyData: Data(),
                contentType: nil,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func makeSession(for request: RESTRequest) -> URLSession {
        guard request.settings.allowsInvalidSSLCertificates else {
            return .shared
        }

        return URLSession(
            configuration: .default,
            delegate: InvalidCertificateBypassDelegate(),
            delegateQueue: nil
        )
    }

    private func makeURLRequest(from request: RESTRequest) throws -> URLRequest {
        guard var components = URLComponents(string: request.url) else {
            throw URLError(.badURL)
        }

        var queryItems = components.queryItems ?? []
        for item in request.queryItems where item.isEnabled && !item.name.isEmpty {
            queryItems.append(URLQueryItem(name: item.name, value: item.value))
        }

        if request.auth.kind == .apiKey,
           request.auth.apiKeyLocation == .query,
           !request.auth.apiKeyName.isEmpty {
            queryItems.append(URLQueryItem(name: request.auth.apiKeyName, value: request.auth.apiKeyValue))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        for header in request.headers where header.isEnabled && !header.name.isEmpty {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.name)
        }

        switch request.auth.kind {
        case .none:
            break
        case .basic:
            let credentials = "\(request.auth.username):\(request.auth.password)"
            if let encoded = credentials.data(using: .utf8)?.base64EncodedString() {
                urlRequest.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
            }
        case .bearer:
            if !request.auth.token.isEmpty {
                urlRequest.setValue("Bearer \(request.auth.token)", forHTTPHeaderField: "Authorization")
            }
        case .apiKey:
            if request.auth.apiKeyLocation == .header, !request.auth.apiKeyName.isEmpty {
                urlRequest.setValue(request.auth.apiKeyValue, forHTTPHeaderField: request.auth.apiKeyName)
            }
        }

        switch request.bodyMode {
        case .raw:
            let body = request.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                urlRequest.httpBody = body.data(using: .utf8)
                if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        case .formURLEncoded:
            let body = Self.formURLEncodedBody(from: request.urlEncodedBodyItems)
            if !body.isEmpty {
                urlRequest.httpBody = body.data(using: .utf8)
                if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                    urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
        }

        return urlRequest
    }

    static func formURLEncodedBody(from items: [HeaderItem]) -> String {
        items
            .filter { $0.isEnabled && !$0.name.isEmpty }
            .map { "\(formPercentEncoded($0.name))=\(formPercentEncoded($0.value))" }
            .joined(separator: "&")
    }

    private static func formPercentEncoded(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        return string
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: "%20", with: "+") ?? string
    }

    private func makeDisplayBody(data: Data, contentType: String?) -> String {
        if isBinaryAudio(data: data, contentType: contentType) {
            return ""
        }

        if data.count <= prettyPrintLimit,
           isLikelyJSON(data: data, contentType: contentType),
           let object = try? JSONSerialization.jsonObject(with: data),
           let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let string = String(data: formatted, encoding: .utf8) {
            return string
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func isLikelyJSON(data: Data, contentType: String?) -> Bool {
        let lowercasedType = contentType?.lowercased() ?? ""
        if lowercasedType.contains("json") {
            return true
        }

        guard let firstByte = data.first(where: { !$0.isASCIIWhitespace }) else {
            return false
        }
        return firstByte == UInt8(ascii: "{") || firstByte == UInt8(ascii: "[")
    }

    private func isBinaryAudio(data: Data, contentType: String?) -> Bool {
        let lowercasedType = contentType?.lowercased() ?? ""
        return lowercasedType.contains("audio/")
            || data.starts(with: [0x49, 0x44, 0x33])
            || data.starts(with: [0xFF, 0xFB])
            || data.starts(with: [0x52, 0x49, 0x46, 0x46])
    }
}

private extension UInt8 {
    var isASCIIWhitespace: Bool {
        self == UInt8(ascii: " ")
            || self == UInt8(ascii: "\n")
            || self == UInt8(ascii: "\r")
            || self == UInt8(ascii: "\t")
    }
}

private final class InvalidCertificateBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        return (.useCredential, URLCredential(trust: serverTrust))
    }
}
