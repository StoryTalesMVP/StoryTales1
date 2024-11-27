//
//  ProfileView.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) var authManager
    @StateObject private var lobbyManager: LobbyManager
    @State private var selectedStory: Lobby?
    @State private var showingPersonalStories = false
    @State private var showingImagePicker = false
    @State private var showingImageSource = false
    @State private var selectedImage: UIImage?
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(authManager: AuthManager) {
        _lobbyManager = StateObject(wrappedValue: LobbyManager(authManager: authManager))
    }
    
    var personalStories: [Lobby] {
        guard let userId = authManager.user?.uid else { return [] }
        return lobbyManager.completedStories.filter { story in
            story.players.keys.contains(userId)
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
                        // Profile Image
                        Button(action: { showingImageSource = true }) {
                            if let imageData = authManager.userProfile?.imageData {
                                Image(base64String: imageData) // Using our custom initializer
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(radius: 5)
                            } else {
                                defaultProfileImage
                            }
                        }
                        
                        // User Info
                        VStack(spacing: 8) {
                            Text(authManager.userProfile?.username ?? "Username")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(authManager.userProfile?.email ?? "Email")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("\(authManager.userProfile?.firstName ?? "") \(authManager.userProfile?.lastName ?? "")")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 32)
                    
                    // Stats Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Story Stats")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 20) {
                            StatCard(
                                title: "Stories",
                                value: "\(personalStories.count)",
                                icon: "book.fill"
                            )
                            
                            StatCard(
                                title: "Contributions",
                                value: "\(countContributions())",
                                icon: "text.quote"
                            )
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // Recent Stories Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Stories")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("See All") {
                                showingPersonalStories = true
                            }
                            .foregroundColor(.blue)
                        }
                        
                        if personalStories.isEmpty {
                            Text("No stories yet")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(personalStories.prefix(3)) { story in
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        authManager.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(item: $selectedStory) { story in
                StoryDetailView(story: story)
            }
            .sheet(isPresented: $showingPersonalStories) {
                PersonalStoriesView(stories: personalStories)
            }
            .confirmationDialog("Update Profile Picture", isPresented: $showingImageSource) {
                Button("Camera") {
                    imageSource = .camera
                    showingImagePicker = true
                }
                Button("Photo Library") {
                    imageSource = .photoLibrary
                    showingImagePicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage,
                          isPresented: $showingImagePicker,
                          sourceType: imageSource)
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if let image = newValue {
                    updateProfileImage(image)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                lobbyManager.startObservingCompletedStories()
            }
            .onDisappear {
                lobbyManager.stopObservingCompletedStories()
            }
        }
    }
    
    private var defaultProfileImage: some View {
        Image(authManager.userProfile?.avatar ?? "Boy1")
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(radius: 5)
    }
    
    private func countContributions() -> Int {
        var count = 0
        for story in personalStories {
            let content = story.story?.content ?? ""
            count += content.components(separatedBy: "\n\n").count
        }
        return count
    }
    
    private func updateProfileImage(_ image: UIImage) {
        Task {
            do {
                try await authManager.updateProfileImage(image)
                await MainActor.run {
                    selectedImage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PersonalStoryCard: View {
    let story: Lobby
    
    var formattedDate: String {
        guard let timestamp = story.story?.lastUpdated else { return "" }
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(story.title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text("\(story.players.count) authors • \(formattedDate)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PersonalStoriesView: View {
    let stories: [Lobby]
    @Environment(\.dismiss) var dismiss
    @State private var selectedStory: Lobby?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(stories) { story in
                        PersonalStoryCard(story: story)
                            .onTapGesture {
                                selectedStory = story
                            }
                    }
                }
                .padding()
            }
            .background(
                Image("StoryTalesBackground")
                    .resizable()
                    .ignoresSafeArea()
            )
            .navigationTitle("My Stories")
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
        }
    }
}

#Preview {
    let authManager = AuthManager()
    return ProfileView(authManager: authManager)
        .environment(authManager)
}
