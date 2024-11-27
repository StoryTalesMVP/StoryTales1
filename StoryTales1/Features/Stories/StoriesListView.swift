//
//  StoriesListView.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import SwiftUI

struct StoriesListView: View {
    @Environment(AuthManager.self) var authManager
    @StateObject private var lobbyManager: LobbyManager
    @State private var selectedStory: Lobby?
    @State private var searchText = ""
    
    init(authManager: AuthManager) {
        _lobbyManager = StateObject(wrappedValue: LobbyManager(authManager: authManager))
    }
    
    var filteredStories: [Lobby] {
        if searchText.isEmpty {
            return completedStories
        }
        return completedStories.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.story?.content.localizedCaseInsensitiveContains(searchText) ?? false ||
            $0.players.values.contains(where: { player in
                player.username.localizedCaseInsensitiveContains(searchText) ||
                player.email.localizedCaseInsensitiveContains(searchText)
            })
        }
    }
    
    var completedStories: [Lobby] {
        lobbyManager.completedStories.sorted {
            ($0.story?.lastUpdatedDate ?? Date()) > ($1.story?.lastUpdatedDate ?? Date())
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
                    
                    if filteredStories.isEmpty {
                        if searchText.isEmpty {
                            ContentUnavailableView("No Stories Yet",
                                                 systemImage: "book.closed",
                                                 description: Text("Completed stories will appear here"))
                        } else {
                            ContentUnavailableView("No Results",
                                                 systemImage: "magnifyingglass",
                                                 description: Text("Try searching with different keywords"))
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredStories) { story in
                                    StoryCardView(story: story)
                                        .onTapGesture {
                                            selectedStory = story
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Stories")
            .navigationBarTitleDisplayMode(.inline)
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

struct StoryCardView: View {
    let story: Lobby
    
    var formattedDate: String {
        guard let timestamp = story.story?.lastUpdated else { return "" }
        
        // Convert Firebase timestamp (milliseconds) to Date
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return "Today at \(timeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return "Yesterday at \(timeFormatter.string(from: date))"
        } else {
            return formatter.string(from: date)
        }
    }
    
    var previewContent: String {
        String(story.story?.content.prefix(100) ?? "") + "..."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("By \(story.players.values.map { $0.username }.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if !previewContent.isEmpty {
                Text(previewContent)
                    .lineLimit(3)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Author avatars with larger size
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -12) {
                    ForEach(Array(story.players.values), id: \.email) { player in
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 36, height: 36)
                            
                            Image(player.avatar)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
                                )
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let authManager = AuthManager()
    return StoriesListView(authManager: authManager)
        .environment(authManager)
}
