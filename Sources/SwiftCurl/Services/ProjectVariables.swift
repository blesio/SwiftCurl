import Foundation

enum ProjectVariables {
    static func resolving(_ request: RESTRequest, with variables: [HeaderItem]) -> RESTRequest {
        let values = dictionary(from: variables)
        var resolved = request
        resolved.url = substitute(request.url, values: values)
        resolved.headers = resolve(request.headers, values: values)
        resolved.queryItems = resolve(request.queryItems, values: values)
        resolved.urlEncodedBodyItems = resolve(request.urlEncodedBodyItems, values: values)
        resolved.body = substitute(request.body, values: values)
        resolved.auth.username = substitute(request.auth.username, values: values)
        resolved.auth.password = substitute(request.auth.password, values: values)
        resolved.auth.token = substitute(request.auth.token, values: values)
        resolved.auth.apiKeyName = substitute(request.auth.apiKeyName, values: values)
        resolved.auth.apiKeyValue = substitute(request.auth.apiKeyValue, values: values)
        return resolved
    }

    static func capturedValues(from response: ResponseRecord, rules: [VariableCapture]) -> [String: String] {
        var result: [String: String] = [:]
        var json: Any?

        for rule in rules where rule.isEnabled {
            let path = rule.path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { continue }
            let enteredName = rule.variableName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = enteredName.isEmpty ? inferredVariableName(from: path) : enteredName
            guard !name.isEmpty else { continue }

            switch rule.source {
            case .responseHeader:
                if let value = response.headers.first(where: {
                    $0.key.caseInsensitiveCompare(path) == .orderedSame
                })?.value {
                    result[name] = value
                }
            case .jsonBody:
                if json == nil {
                    json = try? JSONSerialization.jsonObject(with: response.bodyData)
                }
                if let value = json.flatMap({ jsonValue(at: path, in: $0) }) {
                    result.merge(variableValues(from: value, named: name)) { _, latest in latest }
                }
            }
        }
        return result
    }

    private static func dictionary(from variables: [HeaderItem]) -> [String: String] {
        variables.reduce(into: [:]) { result, item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if item.isEnabled && !name.isEmpty { result[name] = item.value }
        }
    }

    private static func resolve(_ items: [HeaderItem], values: [String: String]) -> [HeaderItem] {
        items.map { item in
            var item = item
            item.name = substitute(item.name, values: values)
            item.value = substitute(item.value, values: values)
            return item
        }
    }

    private static func substitute(_ string: String, values: [String: String]) -> String {
        values.reduce(string) { result, pair in
            result.replacingOccurrences(of: "{{\(pair.key)}}", with: pair.value)
        }
    }

    private static func jsonValue(at rawPath: String, in root: Any) -> Any? {
        var path = rawPath
        if path == "$" { return root }
        if path.hasPrefix("$.") { path.removeFirst(2) }
        let components = path.replacingOccurrences(of: "[", with: ".")
            .replacingOccurrences(of: "]", with: "")
            .split(separator: ".")
            .map(String.init)
        let value = jsonValue(in: root, components: ArraySlice(components))
        if let value { return value }

        // A single key is convenient for common responses that wrap their payload
        // (for example { "Value": { "LoginToken": "..." } }).
        if components.count == 1 {
            return nestedJSONValue(forKey: components[0], in: root)
        }
        return nil
    }

    private static func jsonValue(in current: Any, components: ArraySlice<String>) -> Any? {
        guard let component = components.first else { return current }
        let remaining = components.dropFirst()

        if let object = current as? [String: Any], let child = object[component] {
            return jsonValue(in: child, components: remaining)
        }

        if let array = current as? [Any] {
            if let index = Int(component), array.indices.contains(index) {
                return jsonValue(in: array[index], components: remaining)
            }

            // When the path names a property after an array, project that path
            // across every element. AgentInfoList.Extension is therefore
            // equivalent to collecting each AgentInfoList[n].Extension.
            let matches = array.compactMap {
                jsonValue(in: $0, components: components)
            }
            return matches.isEmpty ? nil : matches
        }

        return nil
    }

    private static func nestedJSONValue(forKey key: String, in value: Any) -> Any? {
        if let object = value as? [String: Any] {
            if let match = object[key] { return match }
            for child in object.values {
                if let match = nestedJSONValue(forKey: key, in: child) { return match }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let match = nestedJSONValue(forKey: key, in: child) { return match }
            }
        }
        return nil
    }

    private static func inferredVariableName(from path: String) -> String {
        path.replacingOccurrences(of: "[", with: ".")
            .replacingOccurrences(of: "]", with: "")
            .split(separator: ".")
            .last
            .map(String.init) ?? path
    }

    private static func string(from value: Any) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        if value is NSNull { return nil }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private static func variableValues(from value: Any, named name: String) -> [String: String] {
        guard let array = value as? [Any] else {
            return string(from: value).map { [name: $0] } ?? [:]
        }

        return array.enumerated().reduce(into: [:]) { result, item in
            let variableName = item.offset == 0 ? name : "\(name)\(item.offset)"
            if let value = string(from: item.element) {
                result[variableName] = value
            }
        }
    }
}
