import SwiftUI
import Quackback

@main
struct QuackbackExampleApp: App {
    init() {
        Quackback.configure(QuackbackConfig(appId: "example", baseURL: URL(string: "http://localhost:3000")!))
        // In production, call Quackback.identify(ssoToken:) with a server-signed token
        Quackback.identify(userId: "user_example", email: "demo@example.com", name: "Demo User")
        Quackback.on(.vote) { print("[Quackback] vote:", $0) }
        Quackback.on(.submit) { print("[Quackback] submit:", $0) }
        Quackback.showLauncher()
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
