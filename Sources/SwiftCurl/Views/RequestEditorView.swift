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
                    .onChange(of: request) { _, _ in store.save() }

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

            RequestSettingsTab(settings: $request.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .padding(.top, 8)
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
                Text("JSON Body")
                    .font(.headline)

                Spacer()

                Button {
                    store.formatSelectedJSONBody()
                } label: {
                    Label("Format JSON", systemImage: "curlybraces")
                }
            }

            TextEditor(text: $request.body)
                .font(.system(.body, design: .monospaced))
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
