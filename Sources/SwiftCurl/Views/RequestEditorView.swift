import SwiftUI

struct RequestEditorView: View {
    @Binding var request: RESTRequest
    @Bindable var store: RequestStore
    @Binding var showingCurl: Bool

    var body: some View {
        VStack(spacing: 0) {
            RequestHeaderView(request: $request, store: store, showingCurl: $showingCurl)

            Divider()

            VSplitView {
                RequestOptionsTabsView(request: $request, store: store)
                    .frame(minHeight: 240, idealHeight: 315, maxHeight: 380)

                ResponseView(response: store.selectedResponse, isSending: store.isSelectedRequestSending)
                    .frame(minHeight: 360, idealHeight: 620)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct RequestOptionsTabsView: View {
    @Binding var request: RESTRequest
    @Bindable var store: RequestStore

    var body: some View {
        TabView {
            RequestBasicsTab(request: $request)
                .tabItem {
                    Label("Request", systemImage: "link")
                }

            Form {
                AuthEditorView(auth: $request.auth)
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Auth", systemImage: "lock")
            }

            Form {
                KeyValueEditorView(title: "Query Parameters", items: $request.queryItems)
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Query", systemImage: "questionmark.circle")
            }

            Form {
                KeyValueEditorView(title: "Headers", items: $request.headers)
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Headers", systemImage: "list.bullet.rectangle")
            }

            RequestBodyTab(request: $request, store: store)
                .tabItem {
                    Label("Body", systemImage: "curlybraces")
                }

            RequestNotesTab(request: $request)
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }

            RequestVariablesTab(request: $request, store: store)
                .tabItem {
                    Label("Variables", systemImage: "curlybraces.square")
                }

            RequestSettingsTab(settings: $request.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .padding(.top, 8)
    }
}

private struct RequestVariablesTab: View {
    @Binding var request: RESTRequest
    @Bindable var store: RequestStore

    var body: some View {
        Form {
            if let box = store.bindingForSelectedProjectVariables() {
                KeyValueEditorView(
                    title: "Project Variables",
                    items: Binding(get: box.get, set: box.set)
                )
                Text("Use variables anywhere in the request as {{name}}. Values are shared by every request in this project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Capture from this response") {
                ForEach($request.variableCaptures) { $capture in
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Toggle("Enabled", isOn: $capture.isEnabled)
                                .labelsHidden()
                        }
                        .frame(width: 48)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Save as variable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Defaults to final path component", text: $capture.variableName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Source")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $capture.source) {
                                ForEach(VariableCaptureSource.allCases) { source in
                                    Text(source.rawValue).tag(source)
                                }
                            }
                            .labelsHidden()
                        }
                        .frame(width: 145)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(capture.source == .jsonBody ? "JSON path or key" : "Header name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField(capture.source == .jsonBody ? "e.g. Value.LoginToken" : "e.g. X-Auth-Token", text: $capture.path)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            request.variableCaptures.removeAll { $0.id == capture.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Button {
                    request.variableCaptures.append(VariableCapture())
                } label: {
                    Label("Add Capture", systemImage: "plus")
                }

                Text("The variable name is optional. When empty, it uses the final JSON path component or header name automatically. A single JSON key also searches nested response objects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct RequestBasicsTab: View {
    @Binding var request: RESTRequest

    var body: some View {
        Form {
            Section("Request") {
                TextField("Name", text: $request.name)
                Picker("Method", selection: $request.method) {
                    ForEach(HTTPMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                TextField("URL", text: $request.url)
            }
        }
        .formStyle(.grouped)
    }
}

private struct RequestBodyTab: View {
    @Binding var request: RESTRequest
    @Bindable var store: RequestStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Body")
                    .font(.headline)

                Spacer()

                if request.bodyMode == .raw {
                    Button {
                        store.formatSelectedJSONBody()
                    } label: {
                        Label("Format JSON", systemImage: "curlybraces")
                    }
                }
            }

            Picker("Body type", selection: $request.bodyMode) {
                ForEach(BodyMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch request.bodyMode {
                case .raw:
                    TextEditor(text: $request.body)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.separator)
                        }
                case .formURLEncoded:
                    Form {
                        KeyValueEditorView(title: "Form Fields", items: $request.urlEncodedBodyItems)
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .padding()
    }
}

private struct RequestNotesTab: View {
    @Binding var request: RESTRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.headline)

            TextEditor(text: $request.notes)
                .scrollContentBackground(.hidden)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator)
                }
        }
        .padding()
    }
}

private struct RequestSettingsTab: View {
    @Binding var settings: RequestSettings

    var body: some View {
        Form {
            Section("HTTPS") {
                Toggle("Allow invalid SSL certificates", isOn: $settings.allowsInvalidSSLCertificates)
                    .toggleStyle(.switch)

                Text("Use this only for local development or trusted internal systems. It bypasses certificate validation for this request.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct RequestHeaderView: View {
    @Binding var request: RESTRequest
    @Bindable var store: RequestStore
    @Binding var showingCurl: Bool

    var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: $request.method) {
                ForEach(HTTPMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .frame(width: 116)

            TextField("https://api.example.com/resource", text: $request.url)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await store.sendSelectedRequest() }
            } label: {
                Label("Send", systemImage: "paperplane.fill")
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(store.isSelectedRequestSending)

            Button {
                showingCurl = true
            } label: {
                Label("cURL", systemImage: "terminal")
            }
        }
        .padding()
    }
}
