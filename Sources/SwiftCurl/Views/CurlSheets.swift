import SwiftUI

struct CurlImportView: View {
    @Bindable var store: RequestStore
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import cURL")
                .font(.title3.weight(.semibold))

            TextEditor(text: $store.curlImportText)
                .font(.system(.body, design: .monospaced))
                .frame(width: 720, height: 260)
                .border(.separator)

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }

                Button("Import") {
                    store.importCurlIntoSelectedProject()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

struct CurlExportView: View {
    @Bindable var store: RequestStore
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated cURL")
                .font(.title3.weight(.semibold))

            TextEditor(text: $store.curlExportText)
                .font(.system(.body, design: .monospaced))
                .frame(width: 720, height: 260)
                .border(.separator)

            HStack {
                Text("Select the command text to copy it.")
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}
