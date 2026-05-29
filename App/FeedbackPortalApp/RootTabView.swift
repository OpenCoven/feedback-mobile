import FeedbackKit
import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        TabView {
            FeedTabView()
                .tabItem {
                    Label("Feedback", systemImage: "bubble.left.and.bubble.right")
                }

            ChangelogTabView()
                .tabItem {
                    Label("Changelog", systemImage: "clock.arrow.circlepath")
                }

            HelpTabView()
                .tabItem {
                    Label("Help", systemImage: "questionmark.circle")
                }

            AccountTabView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
        }
    }
}
