//
//  LobbyListView.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import SwiftUI

struct LobbyListView: View {
    @Environment(AuthManager.self) var authManager
    @StateObject private var lobbyManager: LobbyManager
    @State private var showingCreateLobby = false
    @State private var selectedLobby: Lobby?
    @State private var searchText = ""
    
    init(authManager: AuthManager) {
        _lobbyManager = StateObject(wrappedValue: LobbyManager(authManager: authManager))
    }
    
    var filteredLobbies: [Lobby] {
        if searchText.isEmpty {
            return lobbyManager.lobbies
        }
        return lobbyManager.lobbies.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
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
                    
                    if filteredLobbies.isEmpty {
                        ContentUnavailableView {
                            Label("No Active Lobbies", systemImage: "book.closed")
                        } description: {
                            Text("Create a new lobby to start your story")
                        } actions: {
                            Button(action: { showingCreateLobby = true }) {
                                Text("Create Lobby")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(filteredLobbies) { lobby in
                                    LobbyCardView(lobby: lobby) {
                                        selectedLobby = lobby
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("Story Tales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateLobby = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign out") {
                        authManager.signOut()
                    }
                }
            }
            .sheet(isPresented: $showingCreateLobby) {
                CreateLobbyView(lobbyManager: lobbyManager) { newLobby in
                    selectedLobby = newLobby
                }
            }
            .sheet(item: $selectedLobby) { lobby in
                LobbyDetailView(
                    lobbyManager: lobbyManager,
                    lobby: lobby,
                    onDismiss: {
                        selectedLobby = nil
                    }
                )
            }
        }
    }
}

struct LobbyCardView: View {
    let lobby: Lobby
    let onJoin: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Image with gradient overlay
            ZStack(alignment: .bottomLeading) {
                Image("StoryBook")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(UIColor.systemBackground)
                            .opacity(0.1)
                    )
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.5),
                        Color.clear
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 80)
                
                // Title overlay on the image
                Text(lobby.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding([.horizontal, .bottom], 16)
                    .padding(.top, 40)
            }
            
            // Content
            VStack(spacing: 16) {
                // Description and Status
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(lobby.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        StatusBadge(status: lobby.status)
                    }
                }
                
                Divider()
                
                // Players and Join Button
                HStack(alignment: .center) {
                    // Player avatars
                    HStack(spacing: -12) {
                        ForEach(Array(lobby.players.values.prefix(3)), id: \.email) { player in
                            if let imageData = player.imageData {
                                Image(base64String: imageData)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(UIColor.systemBackground), lineWidth: 2)
                                    )
                                    .shadow(radius: 1)
                            } else {
                                Image(player.avatar)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(UIColor.systemBackground), lineWidth: 2)
                                    )
                                    .shadow(radius: 1)
                            }
                        }
                        
                        if lobby.players.count > 3 {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                Text("+\(lobby.players.count - 3)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.systemBackground), lineWidth: 2)
                            )
                        }
                    }
                    .padding(.trailing, 8)
                    
                    Text("\(lobby.players.count)/\(lobby.maxPlayers)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Join button
                    Button(action: onJoin) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill.badge.plus")
                                .font(.caption)
                            Text("Join Story")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(lobby.players.count >= lobby.maxPlayers ? Color.gray : Color.blue)
                        .clipShape(Capsule())
                    }
                    .disabled(lobby.players.count >= lobby.maxPlayers)
                }
            }
            .padding(16)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 5, x: 0, y: 2)
    }
}


struct StatusBadge: View {
    let status: Lobby.LobbyStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.2))
            )
            .foregroundColor(statusColor)
    }
    
    private var statusColor: Color {
        switch status {
        case .waiting:
            return .blue
        case .inProgress:
            return .green
        case .completed:
            return .gray
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search stories...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


#Preview {
    let authManager = AuthManager()
    return LobbyListView(authManager: authManager)
        .environment(authManager)
}
