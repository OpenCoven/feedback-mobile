import FeedbackKit
import SwiftUI

struct ChangelogTabView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var vm: ChangelogViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    ChangelogListView(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Changelog")
        }
        .task {
            let model = ChangelogViewModel(api: env.api)
            vm = model
            await model.load()
        }
    }
}

private struct ChangelogListView: View {
    @ObservedObject var vm: ChangelogViewModel

    var body: some View {
        List {
            if vm.isLoading && vm.entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else if let error = vm.errorMessage, vm.entries.isEmpty {
                ContentUnavailableView(
                    "Couldn't Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .listRowSeparator(.hidden)
            } else if vm.entries.isEmpty {
                ContentUnavailableView(
                    "No Entries Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Check back for updates.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title)
                            .font(.headline)
                        if let publishedAt = entry.publishedAt {
                            Text(publishedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let content = entry.content, !content.isEmpty {
                            Text(content)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await vm.load()
        }
    }
}
