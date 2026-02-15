//
//  ManageFriendsView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct ManageFriendsView: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var showingAddFriend = false
    @State private var friendToRemove: Friend?
    @State private var showingRemoveConfirm = false
    
    var body: some View {
        List {
            globalVisibilitySection
            
            if !viewModel.friends.isEmpty {
                individualFriendsSection
            }
        }
        .navigationTitle("Manage Friends")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingAddFriend, onDismiss: {
            // Guarantee we remain in Settings tab after dismissing
            // by explicitly ensuring the TabView selection stays on Settings
            NotificationCenter.default.post(name: Notification.Name("SelectTabIndex"), object: 2)
        }) {
            AddFriendView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Remove Friend?",
            isPresented: $showingRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let friend = friendToRemove {
                    viewModel.removeFriend(friend)
                }
                friendToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                friendToRemove = nil
            }
        } message: {
            if let friend = friendToRemove {
                Text("Are you sure you want to remove \(friend.name) from your friends?")
            }
        }
    }
    
    private var globalVisibilitySection: some View {
        Section {
            Toggle("Share Status with All Friends", isOn: Binding(
                get: { viewModel.globalStatusVisibility },
                set: { newValue in
                    viewModel.globalStatusVisibility = newValue
                    viewModel.setAllFriendsVisibility(newValue)
                }
            ))
        } footer: {
            Text("When disabled, your status will be hidden from all friends. When enabled, use individual toggles below to control visibility per friend.")
                .foregroundColor(.secondary)
        }
    }
    
    private var individualFriendsSection: some View {
        Section {
            ForEach(viewModel.friends) { friend in
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(friend.name)
                                .font(.headline)
                            
                            if ContactVerificationManager.shared.isPhoneNumberInContacts(friend.phoneNumber) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                        
                        Text(friend.phoneNumber)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { friend.canSeeMyStatus },
                            set: { viewModel.updateFriendVisibility(friend: friend, canSee: $0) }
                        ))
                        .disabled(!viewModel.globalStatusVisibility)
                        
                        Button("Remove") {
                            friendToRemove = friend
                            showingRemoveConfirm = true
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.red, lineWidth: 1)
                        )
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let friend = viewModel.friends[index]
                    friendToRemove = friend
                    showingRemoveConfirm = true
                }
            }
        } header: {
            Text("Individual Status Visibility")
        } footer: {
            Text("Toggle individual friends' ability to see your status. Use the Remove button or swipe to delete. ✓ indicates the person is in your contacts.")
                .foregroundColor(.secondary)
        }
    }
}

