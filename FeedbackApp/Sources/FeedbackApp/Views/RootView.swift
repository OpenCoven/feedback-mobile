import OpenCovenFeedback
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appConfig: AppConfiguration

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { HomeView() }
            } else {
                NavigationView { HomeView() }
            }
        }
        .onAppear {
            OpenCovenFeedback.showLauncher()
        }
    }
}
