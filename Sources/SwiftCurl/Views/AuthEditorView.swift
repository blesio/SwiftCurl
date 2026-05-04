import SwiftUI

struct AuthEditorView: View {
    @Binding var auth: AuthConfig
    @State private var showsBearerToken = false

    var body: some View {
        Section("Authentication") {
            Picker("Type", selection: $auth.kind) {
                ForEach(AuthKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }

            switch auth.kind {
            case .none:
                EmptyView()
            case .basic:
                TextField("Username", text: $auth.username)
                SecureField("Password", text: $auth.password)
            case .bearer:
                LabeledContent("Token") {
                    HStack(spacing: 12) {
                        ZStack {
                            TextField("Token", text: $auth.token)
                                .textFieldStyle(.roundedBorder)
                                .opacity(showsBearerToken ? 1 : 0)

                            SecureField("Token", text: $auth.token)
                                .textFieldStyle(.roundedBorder)
                                .opacity(showsBearerToken ? 0 : 1)
                        }
                        .frame(minWidth: 420, maxWidth: .infinity)

                        Toggle("Show", isOn: $showsBearerToken)
                            .toggleStyle(.switch)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                }
            case .apiKey:
                TextField("Key", text: $auth.apiKeyName)
                SecureField("Value", text: $auth.apiKeyValue)
                Picker("Add to", selection: $auth.apiKeyLocation) {
                    ForEach(APIKeyLocation.allCases) { location in
                        Text(location.rawValue).tag(location)
                    }
                }
            }
        }
    }
}
