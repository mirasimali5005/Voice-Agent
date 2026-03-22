import SwiftUI

struct MainTabView: View {
    @ObservedObject var appState: AppState
    let databaseManager: DatabaseManager
    var syncManager: SyncManager?
    var authManager: AuthManager?

    @State private var selectedTab = 0

    private let bgColor = Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab bar at top
                tabBar

                Divider()
                    .background(Color.white.opacity(0.06))

                // Content
                Group {
                    switch selectedTab {
                    case 0:
                        HistoryView(appState: appState, databaseManager: databaseManager)
                    case 1:
                        SettingsView(
                            appState: appState,
                            databaseManager: databaseManager,
                            syncManager: syncManager,
                            authManager: authManager
                        )
                    default:
                        HistoryView(appState: appState, databaseManager: databaseManager)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 620, minHeight: 480)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "History", icon: "clock.arrow.circlepath", index: 0)
            tabButton(title: "Settings", icon: "gearshape", index: 1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.02))
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.4))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(selectedTab == index ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.borderless)
    }
}
