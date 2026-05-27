import OpenCovenFeedback
import SwiftUI

@main
struct FeedbackAppApp: App {
    @StateObject private var appConfig = AppConfiguration()

    init() {
        AppConfiguration.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appConfig)
        }
    }
}
