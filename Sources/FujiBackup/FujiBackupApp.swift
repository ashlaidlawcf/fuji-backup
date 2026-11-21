import SwiftUI

@main
struct FujiBackupApp: App {
    #if DEBUG
    @State private var model = DebugSnapshot.model()
    #else
    @State private var model = AppModel()
    #endif

    var body: some Scene {
        Window("Fuji Backup", id: "main") {
            ContentView(model: model)
            #if DEBUG
                .task { await DebugSnapshot.takeIfRequested() }
            #endif
        }
        .defaultSize(width: 500, height: 580)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
