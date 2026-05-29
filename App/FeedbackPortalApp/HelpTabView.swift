import FeedbackKit
import SwiftUI

struct HelpTabView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var vm: HelpViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    HelpListView(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Help")
        }
        .task {
            let model = HelpViewModel(api: env.api)
            vm = model
            await model.load()
        }
    }
}

private struct HelpListView: View {
    @ObservedObject var vm: HelpViewModel

    var body: some View {
        List {
            if vm.isLoading && vm.categories.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else if let error = vm.errorMessage, vm.categories.isEmpty {
                ContentUnavailableView(
                    "Couldn't Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .listRowSeparator(.hidden)
            } else if vm.categories.isEmpty {
                ContentUnavailableView(
                    "No Categories",
                    systemImage: "questionmark.circle",
                    description: Text("No help content available yet.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.categories) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.headline)
                        if let description = category.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
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
