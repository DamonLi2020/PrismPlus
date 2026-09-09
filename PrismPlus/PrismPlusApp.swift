import SwiftUI

@main
struct PrismPlusApp: App {
    var body: some Scene {
        WindowGroup {
            WorkspaceView()
        }
        .defaultSize(width: 1_360, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    NotificationCenter.default.post(name: .newLaTeXDocument, object: nil)
                }
                .keyboardShortcut("n")

                Button("Open…") {
                    NotificationCenter.default.post(name: .openLaTeXDocument, object: nil)
                }
                .keyboardShortcut("o")

                Button("Open Project…") {
                    NotificationCenter.default.post(name: .openLaTeXProject, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .saveLaTeXDocument, object: nil)
                }
                .keyboardShortcut("s")
            }

            CommandMenu("LaTeX") {
                Button("Compile") {
                    NotificationCenter.default.post(name: .compileLaTeXDocument, object: nil)
                }
                .keyboardShortcut("b")

                Button("Format Document") {
                    NotificationCenter.default.post(name: .formatLaTeXDocument, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let compileLaTeXDocument = Notification.Name("compileLaTeXDocument")
    static let newLaTeXDocument = Notification.Name("newLaTeXDocument")
    static let openLaTeXDocument = Notification.Name("openLaTeXDocument")
    static let openLaTeXProject = Notification.Name("openLaTeXProject")
    static let saveLaTeXDocument = Notification.Name("saveLaTeXDocument")
    static let formatLaTeXDocument = Notification.Name("formatLaTeXDocument")
}
