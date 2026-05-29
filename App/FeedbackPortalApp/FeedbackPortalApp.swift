import FeedbackKit
import SwiftUI

@main
struct FeedbackPortalApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(env)
                .environmentObject(env.auth)
        }
    }
}
