import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SwiftCurlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = RequestStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .defaultSize(width: 1440, height: 920)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Request") {
                    store.addRequest()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Run Request") {
                    Task { await store.sendSelectedRequest() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(store.selectedRequest == nil || store.isSelectedRequestSending)
            }
        }
    }
}
