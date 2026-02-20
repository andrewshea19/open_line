//
//  FriendsView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct FriendsView: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var showingAddFriend = false
    @State private var showingFriendRequests = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status toggle at top
                    TurretStatusPanel(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Friends list
                    if viewModel.friends.isEmpty {
                        EmptyFriendsView()
                            .padding(.top, 40)
                    } else {
                        friendsList
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Friend requests button (if any pending)
                        if totalPendingRequests > 0 {
                            Button(action: { showingFriendRequests = true }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 17, weight: .medium))

                                    // Badge
                                    Text("\(totalPendingRequests)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }

                        // Add friend button
                        Button(action: { showingAddFriend = true }) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 17, weight: .medium))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingFriendRequests) {
                FriendRequestsView(viewModel: viewModel)
            }
            .refreshable {
                viewModel.syncFriendStatuses()
            }
            .onAppear {
                viewModel.fetchFriendRequests()
            }
        }
    }

    private var totalPendingRequests: Int {
        viewModel.pendingFriendRequests.count + viewModel.sentFriendRequests.count
    }

    // MARK: - Friends List
    private var friendsList: some View {
        VStack(spacing: 20) {
            ForEach(viewModel.getFriendCategories(), id: \.category) { categoryGroup in
                if !categoryGroup.friends.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        TurretSectionHeader(
                            title: categoryGroup.category,
                            count: categoryGroup.friends.count
                        )
                        .padding(.horizontal)

                        VStack(spacing: 2) {
                            ForEach(categoryGroup.friends) { friend in
                                FriendRowView(
                                    friend: friend,
                                    canCall: categoryGroup.category == AppConstants.Category.availableNow,
                                    category: categoryGroup.category
                                )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

}

// MARK: - Empty Friends View

struct EmptyFriendsView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(TurretTheme.ledOff.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: 4)

                Circle()
                    .fill(TurretTheme.panelDark)
                    .frame(width: 70, height: 70)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(TurretTheme.ledOff)
            }

            VStack(spacing: 6) {
                Text("No Friends Yet")
                    .font(TurretTheme.statusFont(size: 18))

                Text("Add friends to see their availability\nand stay connected.")
                    .font(TurretTheme.bodyFont(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
