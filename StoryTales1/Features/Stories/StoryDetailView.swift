//
//  StoryDetailView.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct StoryDetailView: View {
    let story: Lobby
    @Environment(\.dismiss) var dismiss
    @Environment(AuthManager.self) var authManager
    
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let database = Database.database().reference()
    
    var formattedDate: String {
        guard let timestamp = story.story?.lastUpdated else { return "" }
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        return date.formatted(date: .long, time: .shortened)
    }
    
    var fullStoryContent: String {
        story.story?.content ?? ""
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Authors section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Authors")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(story.players.values), id: \.email) { player in
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 48, height: 48)
                                            
                                            if let imageData = player.imageData {
                                                Image(base64String: imageData)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 48, height: 48)
                                                    .clipShape(Circle())
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white, lineWidth: 2)
                                                    )
                                            } else {
                                                Image(player.avatar)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 48, height: 48)
                                                    .clipShape(Circle())
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white, lineWidth: 2)
                                                    )
                                            }
                                        }
                                        .shadow(radius: 2)
                                        
                                        Text(player.username)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Story content
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Story")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(fullStoryContent)
                            .font(.body)
                            .lineSpacing(8)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Comments section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Comments")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // New comment input
                        HStack {
                            TextField("Add a comment...", text: $newCommentText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: submitComment) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        }
                        
                        if comments.isEmpty {
                            Text("No comments yet")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            // Comments list
                            ForEach(comments) { comment in
                                CommentView(comment: comment)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .background(
                Image("StoryTalesBackground")
                    .resizable()
                    .ignoresSafeArea()
            )
            .navigationTitle(story.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                observeComments()
            }
        }
    }
    
    private func observeComments() {
        database.child("storyComments").child(story.id).observe(.value) { snapshot in
            var newComments: [Comment] = []
            
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let commentData = try? JSONSerialization.data(withJSONObject: snapshot.value as Any),
                   let comment = try? JSONDecoder().decode(Comment.self, from: commentData) {
                    newComments.append(comment)
                }
            }
            
            DispatchQueue.main.async {
                self.comments = newComments.sorted { $0.timestamp > $1.timestamp }
            }
        }
    }
    
    private func submitComment() {
        guard let userId = Auth.auth().currentUser?.uid,
              let userProfile = authManager.userProfile else {
            return
        }
        
        isLoading = true
        let trimmedComment = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let commentRef = database.child("storyComments").child(story.id).childByAutoId()
        guard let commentId = commentRef.key else { return }
        
        let comment = Comment(
            id: commentId,
            userId: userId,
            username: userProfile.username,
            userAvatar: userProfile.avatar,
            imageData: userProfile.imageData,
            content: trimmedComment,
            timestamp: Date().timeIntervalSince1970 * 1000
        )
        
        do {
            let data = try JSONEncoder().encode(comment)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode comment"])
            }
            
            commentRef.setValue(dict) { error, _ in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        showError = true
                    } else {
                        newCommentText = ""
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct CommentView: View {
    let comment: Comment
    
    var formattedDate: String {
        let date = comment.date
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let imageData = comment.imageData {
                    // Show custom profile picture if available
                    Image(base64String: imageData)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    // Show default avatar if no custom picture
                    Image(comment.userAvatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading) {
                    Text(comment.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(comment.content)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let mockStory = Lobby(
        id: "preview",
        hostId: "host",
        title: "Preview Story",
        description: "A preview story",
        maxPlayers: 4,
        status: .completed,
        gameMode: .timed,
        timerDuration: 60,
        players: [
            "1": Player(
                email: "test@example.com",
                username: "TestUser",
                firstName: "Test",
                lastName: "User",
                avatar: "Boy1",
                joinedAt: Date()
            )
        ],
        story: Story(
            content: "Once upon a time...",
            currentTurn: "1",
            lastUpdated: Date().timeIntervalSince1970,
            timeRemaining: 0,
            totalGameTime: 0
        )
    )
    
    return StoryDetailView(story: mockStory)
        .environment(AuthManager())
}
