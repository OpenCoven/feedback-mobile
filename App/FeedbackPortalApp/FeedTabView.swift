import FeedbackKit
import SwiftUI

struct FeedTabView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var auth: AuthStore

    @State private var vm: FeedViewModel?
    @State private var isShowingSubmit = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    FeedListView(vm: vm, isShowingSubmit: $isShowingSubmit)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Feedback")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSubmit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingSubmit) {
                if let vm {
                    SubmitView(api: env.api, auth: auth)
                }
            }
        }
        .task {
            let model = FeedViewModel(api: env.api)
            vm = model
            await model.load()
        }
    }
}

private struct FeedListView: View {
    @ObservedObject var vm: FeedViewModel
    @Binding var isShowingSubmit: Bool

    var body: some View {
        List {
            if vm.isLoading && vm.posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else if let error = vm.errorMessage, vm.posts.isEmpty {
                ContentUnavailableView(
                    "Couldn't Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .listRowSeparator(.hidden)
            } else if vm.posts.isEmpty {
                ContentUnavailableView(
                    "No Posts Yet",
                    systemImage: "bubble.left",
                    description: Text("Be the first to submit feedback.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.posts) { post in
                    NavigationLink(value: post.id) {
                        PostRowView(post: post)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await vm.load()
        }
        .navigationDestination(for: String.self) { postId in
            PostDetailView(postId: postId)
        }
    }
}

private struct PostRowView: View {
    let post: PostSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Image(systemName: post.hasVoted ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                    .foregroundStyle(post.hasVoted ? .blue : .secondary)
                Text("\(post.voteCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 36)

            Text(post.title)
                .font(.body)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
