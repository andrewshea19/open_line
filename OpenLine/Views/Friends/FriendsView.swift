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
            VStack(spacing: 0) {
                if totalPendingRequests > 0 {
                    friendRequestsBanner
                }
                
                if viewModel.friends.isEmpty {
                    EmptyFriendsView()
                } else {
                    List {
                        ForEach(viewModel.getFriendCategories(), id: \.category) { categoryGroup in
                            if !categoryGroup.friends.isEmpty {
                                Section(categoryGroup.category) {
                                    ForEach(categoryGroup.friends) { friend in
                                        FriendRowView(
                                            friend: friend,
                                            canCall: categoryGroup.category == AppConstants.Category.availableNow,
                                            category: categoryGroup.category
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        viewModel.syncFriendStatuses()
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddFriend = true }) {
                        ModernIconBadge(
                            icon: "plus",
                            color: .blue,
                            size: 28,
                            useNeutralStyle: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingFriendRequests) {
                FriendRequestsView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.fetchFriendRequests()
            }
        }
    }
    
    private var totalPendingRequests: Int {
        viewModel.pendingFriendRequests.count + viewModel.sentFriendRequests.count
    }
    
    private var friendRequestsBanner: some View {
        Button(action: { showingFriendRequests = true }) {
            HStack(spacing: 12) {
                ModernIconBadge(
                    icon: "person.badge.plus.fill",
                    color: .blue,
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.pendingFriendRequests.count > 0 && viewModel.sentFriendRequests.count > 0 {
                        Text("\(viewModel.pendingFriendRequests.count) received, \(viewModel.sentFriendRequests.count) sent")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    } else if viewModel.pendingFriendRequests.count > 0 {
                        Text("\(viewModel.pendingFriendRequests.count) pending friend request\(viewModel.pendingFriendRequests.count == 1 ? "" : "s")")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    } else {
                        Text("\(viewModel.sentFriendRequests.count) sent request\(viewModel.sentFriendRequests.count == 1 ? "" : "s") pending")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    
                    Text("Tap to manage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .glassCard(cornerRadius: 16, padding: 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyFriendsView: View {
    var body: some View {
        VStack(spacing: 24) {
            ModernIconBadge(
                icon: "person.2.fill",
                color: .secondary,
                size: 80
            )
            
            VStack(spacing: 8) {
                Text("No Friends Added Yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("Add friends to see their availability and stay connected! Your friends need to accept your request before you can see their status.\n\nWe'll verify if people are in your contacts for added security.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
