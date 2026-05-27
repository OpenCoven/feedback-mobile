import SwiftUI
import OpenCovenFeedback

@main
struct OpenCovenFeedbackExampleApp: App {
    init() {
        OpenCovenFeedback.configure(OpenCovenFeedbackConfig(instanceUrl: URL(string: "http://localhost:3000")!))
        // In production, call OpenCovenFeedback.identify(ssoToken:) with a server-signed token
        OpenCovenFeedback.identify(userId: "user_example", email: "demo@example.com", name: "Demo User")
        OpenCovenFeedback.on(.vote) { print("[OpenCovenFeedback] vote:", $0) }
        OpenCovenFeedback.on(.submit) { print("[OpenCovenFeedback] submit:", $0) }
        OpenCovenFeedback.showLauncher()
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
