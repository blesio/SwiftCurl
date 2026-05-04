import SwiftUI

struct KeyValueEditorView: View {
    let title: String
    @Binding var items: [HeaderItem]

    var body: some View {
        Section(title) {
            if items.isEmpty {
                Text("No \(title.lowercased()) added")
                    .foregroundStyle(.secondary)
            }

            ForEach($items) { $item in
                HStack {
                    Toggle("", isOn: $item.isEnabled)
                        .labelsHidden()
                        .frame(width: 20)

                    TextField("Name", text: $item.name)
                    TextField("Value", text: $item.value)

                    Button {
                        items.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button {
                items.append(HeaderItem(name: "", value: ""))
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }
}
