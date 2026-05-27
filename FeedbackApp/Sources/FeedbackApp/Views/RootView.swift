import OpenCovenFeedback
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appConfig: AppConfiguration

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .onAppear {
            OpenCovenFeedback.showLauncher()
        }
    }
}
