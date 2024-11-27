//
//  UsersView.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/26/24.
//

import SwiftUI

struct UsersView: View {
    @Environment(AuthManager.self) var authManager
    @State private var searchText = ""
    @State private var selectedUser: UserProfile?
    
    var filteredUsers: [UserProfile] {
        if searchText.isEmpty {
            return authManager.allUsers
        }
        return authManager.allUsers.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            "\($0.firstName) \($0.lastName)".localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Image("StoryTalesBackground")
                    .resizable()
                    .ignoresSafeArea()
                
                VStack {
                    // Search bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    if filteredUsers.isEmpty {
                        if searchText.isEmpty {
                            ContentUnavailableView("No Users Yet",
                                                 systemImage: "person.2.slash",
                                                 description: Text("Be the first to invite friends!"))
                        } else {
                            ContentUnavailableView("No Results",
                                                 systemImage: "magnifyingglass",
                                                 description: Text("Try searching with different keywords"))
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredUsers) { user in
                                    UserCardView(user: user)
                                        .onTapGesture {
                                            selectedUser = user
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedUser) { user in
                UserProfileView(user: user)
            }
        }
    }
}

struct UserCardView: View {
    let user: UserProfile
    
    var body: some View {
        HStack(spacing: 16) {
            // User Avatar
            if let imageData = user.imageData {
                Image(base64String: imageData)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else {
                Image(user.avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(user.firstName) \(user.lastName)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct UserProfileView: View {
    let user: UserProfile
    @Environment(\.dismiss) var dismiss
    @Environment(AuthManager.self) var authManager
    @StateObject private var lobbyManager: LobbyManager
    @State private var selectedStory: Lobby?
    
    init(user: UserProfile) {
        self.user = user
        _lobbyManager = StateObject(wrappedValue: LobbyManager(authManager: AuthManager()))
    }
    
    var userStories: [Lobby] {
        lobbyManager.completedStories.filter { story in
            story.players.values.contains { $0.email == user.email }
        }.sorted {
            ($0.story?.lastUpdatedDate ?? Date()) > ($1.story?.lastUpdatedDate ?? Date())
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        if let imageData = user.imageData {
                            Image(base64String: imageData)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        } else {
                            Image(user.avatar)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        }
                        
                        VStack(spacing: 8) {
                            Text(user.username)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("\(user.firstName) \(user.lastName)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 32)
                    
                    // Stories Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Stories")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if userStories.isEmpty {
                            Text("No stories yet")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(userStories) { story in
                                PersonalStoryCard(story: story)
                                    .onTapGesture {
                                        selectedStory = story
                                    }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .background(
                Image("StoryTalesBackground")
                    .resizable()
                    .ignoresSafeArea()
            )
            .navigationTitle("\(user.username)'s Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedStory) { story in
                StoryDetailView(story: story)
            }
            .onAppear {
                lobbyManager.startObservingCompletedStories()
            }
            .onDisappear {
                lobbyManager.stopObservingCompletedStories()
            }
        }
    }
}

#Preview {
    UsersView()
        .environment(AuthManager())
}
