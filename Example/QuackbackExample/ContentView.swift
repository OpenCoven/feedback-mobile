import SwiftUI
import Quackback

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Quackback Example").font(.largeTitle)
            Button("Open Feedback") { Quackback.open() }.buttonStyle(.borderedProminent)
            Button("Open Feature Requests") { Quackback.open(board: "feature-requests") }.buttonStyle(.bordered)
        }.padding()
    }
}
