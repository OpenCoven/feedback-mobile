import SwiftUI
import OpenCovenFeedback

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("OpenCovenFeedback Example").font(.largeTitle)
            Button("Open Feedback") { OpenCovenFeedback.open() }.buttonStyle(.borderedProminent)
            Button("Open Feature Requests") { OpenCovenFeedback.open(board: "feature-requests") }.buttonStyle(.bordered)
        }.padding()
    }
}
