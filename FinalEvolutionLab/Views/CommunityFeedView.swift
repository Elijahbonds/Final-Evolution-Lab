import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseDataConnect
import SocialDataConnect

/// Arena **Community** tab: live posts from Data Connect SQL, with author PRQ / avatar URLs when synced.
struct CommunityFeedView: View {
    @State private var posts: [ListRecentPostsQuery.Data.Post] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                ProgressView("Loading community…")
                    .tint(Theme.brandBlue)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Community unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if posts.isEmpty {
                ContentUnavailableView(
                    "No posts yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Share a system scan or lab result to seed the feed.")
                )
            } else {
                List(posts) { post in
                    communityPostRow(post)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.white.opacity(0.04))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.deepBlack)
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                FELPreviewLabel(text: FELPremiumCopy.Preview.communityFeed)
            }
        }
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    @ViewBuilder
    private func communityPostRow(_ post: ListRecentPostsQuery.Data.Post) -> some View {
        let author = post.author
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                authorAvatar(urlString: author.avatarUrl ?? author.profilePictureUrl)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(author.username)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(relTime(post.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let peak = author.topPRQScore {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.brandCyan)
                            Text("Peak PRQ \(String(format: "%.1f", peak))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.brandCyan)
                            Text("(SQL profile)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Text(post.content)
                .font(.body)
                .foregroundStyle(.primary)

            if post.trainingScore != nil || post.gameModeId != nil || post.feedSource != nil {
                HStack(spacing: 10) {
                    if let mode = post.gameModeId {
                        Label(mode, systemImage: "gamecontroller.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.brandCyan)
                    }
                    if let s = post.trainingScore {
                        Text("Score \(String(format: "%.1f", s))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.brandBlue)
                    }
                    if let src = post.feedSource {
                        Text(src.replacingOccurrences(of: "_", with: " ").uppercased())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func authorAvatar(urlString: String?) -> some View {
        Group {
            if let s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        avatarPlaceholder
                    case .empty:
                        ProgressView()
                            .tint(Theme.brandBlue)
                    @unknown default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            } else {
                avatarPlaceholder
            }
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 40))
            .foregroundStyle(.secondary.opacity(0.85))
            .frame(width: 44, height: 44)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        TrainingLabSocialBridge.shared.configureConnectorIfNeeded()
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            let result = try await DataConnect.socialConnector.listRecentPostsQuery.execute()
            guard let data = result.data else {
                errorMessage = "No feed data returned."
                return
            }
            posts = data.posts
        } catch {
            errorMessage = error.localizedDescription
            let msg = error.localizedDescription
            let offline = (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == URLError.notConnectedToInternet.rawValue
            FelToastCenter.shared.show(
                offline ? "Offline — feed will load when you reconnect." : msg,
                isError: true
            )
        }
    }

    private func relTime(_ ts: Timestamp) -> String {
        let date = ts.dateValue()
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
