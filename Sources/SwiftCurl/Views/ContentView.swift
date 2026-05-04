import SwiftUI

struct ContentView: View {
    @Bindable var store: RequestStore
    @State private var showingImport = false
    @State private var showingCurl = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            if let requestBox = store.bindingForSelectedRequest() {
                RequestEditorView(
                    request: Binding(
                        get: requestBox.get,
                        set: requestBox.set
                    ),
                    store: store,
                    showingCurl: $showingCurl
                )
            } else {
                ContentUnavailableView("No Request Selected", systemImage: "network", description: Text("Create a project or add a request to start."))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingImport = true
                } label: {
                    Label("Import cURL", systemImage: "square.and.arrow.down")
                }

                Button {
                    store.addRequest()
                } label: {
                    Label("New Request", systemImage: "plus")
                }

                Button {
                    Task { await store.sendSelectedRequest() }
                } label: {
                    Label(store.isSelectedRequestSending ? "Sending" : "Send", systemImage: "paperplane.fill")
                }
                .disabled(store.isSelectedRequestSending || store.selectedRequest == nil)
            }
        }
        .sheet(isPresented: $showingImport) {
            CurlImportView(store: store, isPresented: $showingImport)
        }
        .sheet(isPresented: $showingCurl) {
            CurlExportView(store: store, isPresented: $showingCurl)
                .onAppear { store.refreshCurlExport() }
        }
    }
}
