import OpenCovenFeedback
import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#8E3DFF"), Color(hex: "#D26BFF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Share your feedback")
                .font(.title2.bold())
            Text("Help us improve by sharing ideas, reporting bugs, or voting on what matters most.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            FeedbackActionButton(
                title: "Share an idea",
                subtitle: "Feature requests and suggestions",
                icon: "lightbulb.fill",
                color: Color(hex: "#8E3DFF")
            ) {
                OpenCovenFeedback.open(view: .home, board: "feature-requests")
            }

            FeedbackActionButton(
                title: "Report a bug",
                subtitle: "Something not working right?",
                icon: "ladybug.fill",
                color: Color(hex: "#D26BFF")
            ) {
                OpenCovenFeedback.open(view: .newPost, board: "bug-reports")
            }

            FeedbackActionButton(
                title: "What's new",
                subtitle: "See recent updates and releases",
                icon: "newspaper.fill",
                color: .secondary
            ) {
                OpenCovenFeedback.open(view: .changelog)
            }
        }
    }
}

// MARK: - Supporting Views

struct FeedbackActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let red, green, blue: Double
        switch hex.count {
        case 6:
            (red, green, blue) = (Double((rgb >> 16) & 0xFF) / 255,
                         Double((rgb >> 8) & 0xFF) / 255,
                         Double(rgb & 0xFF) / 255)
        default:
            (red, green, blue) = (1, 1, 1)
        }
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack { HomeView() }
    } else {
        NavigationView { HomeView() }
    }
}
