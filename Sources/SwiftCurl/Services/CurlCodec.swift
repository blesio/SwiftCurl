import Foundation

enum CurlCodec {
    static func makeCurl(for request: RESTRequest) -> String {
        var parts = ["curl", "-X", shellQuote(request.method.rawValue), shellQuote(resolvedURL(for: request))]

        for header in request.headers where header.isEnabled && !header.name.isEmpty {
            parts += ["-H", shellQuote("\(header.name): \(header.value)")]
        }

        switch request.auth.kind {
        case .none:
            break
        case .basic:
            parts += ["-u", shellQuote("\(request.auth.username):\(request.auth.password)")]
        case .bearer:
            if !request.auth.token.isEmpty {
                parts += ["-H", shellQuote("Authorization: Bearer \(request.auth.token)")]
            }
        case .apiKey:
            if request.auth.apiKeyLocation == .header, !request.auth.apiKeyName.isEmpty {
                parts += ["-H", shellQuote("\(request.auth.apiKeyName): \(request.auth.apiKeyValue)")]
            }
        }

        if !request.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts += ["--data-raw", shellQuote(request.body)]
        }

        return parts.joined(separator: " ")
    }

    static func parse(_ curl: String) -> RESTRequest? {
        var tokens = tokenize(curl.replacingOccurrences(of: "\\\n", with: " "))
        guard let first = tokens.first, first == "curl" else { return nil }
        tokens.removeFirst()

        var request = RESTRequest(name: "Imported Request")
        var headers: [HeaderItem] = []
        var body = ""
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "-X", "--request":
                request.method = HTTPMethod(rawValue: nextValue(tokens, index: &index).uppercased()) ?? request.method
            case "-H", "--header":
                let value = nextValue(tokens, index: &index)
                if let separator = value.firstIndex(of: ":") {
                    let name = String(value[..<separator]).trimmingCharacters(in: .whitespaces)
                    let headerValue = String(value[value.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                    if name.caseInsensitiveCompare("Authorization") == .orderedSame,
                       headerValue.lowercased().hasPrefix("bearer ") {
                        request.auth.kind = .bearer
                        request.auth.token = String(headerValue.dropFirst(7))
                    } else {
                        headers.append(HeaderItem(name: name, value: headerValue))
                    }
                }
            case "-u", "--user", "--user-basic":
                let value = nextValue(tokens, index: &index)
                let pieces = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                request.auth.kind = .basic
                request.auth.username = pieces.first.map(String.init) ?? ""
                request.auth.password = pieces.dropFirst().first.map(String.init) ?? ""
            case "-d", "--data", "--data-raw", "--data-binary", "--data-ascii":
                body = nextValue(tokens, index: &index)
                if request.method == .get {
                    request.method = .post
                }
            default:
                if !token.hasPrefix("-"), request.url == "https://httpbin.org/get" {
                    request.url = token
                    request.name = URL(string: token)?.host ?? "Imported Request"
                }
            }
            index += 1
        }

        request.headers = headers
        request.body = prettyPrintedJSON(body) ?? body
        return request
    }

    static func prettyPrintedJSON(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        let object = try? JSONSerialization.jsonObject(with: data)
        guard let object else { return nil }
        let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return formatted.flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func resolvedURL(for request: RESTRequest) -> String {
        guard var components = URLComponents(string: request.url) else { return request.url }
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
        return components.url?.absoluteString ?? request.url
    }

    private static func shellQuote(_ string: String) -> String {
        "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func nextValue(_ tokens: [String], index: inout Int) -> String {
        let nextIndex = index + 1
        guard tokens.indices.contains(nextIndex) else { return "" }
        index = nextIndex
        return tokens[nextIndex]
    }

    private static func tokenize(_ input: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var isEscaping = false

        for character in input {
            if isEscaping {
                current.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "'" || character == "\"" {
                quote = character
            } else if character.isWhitespace {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }
}
