//
//  LobbyDetailView.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import SwiftUI
import FirebaseAuth

struct LobbyDetailView: View {
    // MARK: - Properties
    @Environment(\.dismiss) var dismiss
    @StateObject var lobbyManager: LobbyManager
    let lobby: Lobby
    let onDismiss: () -> Void
    
    @State private var isJoining = false
    @State private var showingGame = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLeaving = false
    @State private var localLobby: Lobby?
    @State private var shouldDismissToRoot = false
    
    // MARK: - Computed Properties
    var isHost: Bool {
        lobby.hostId == Auth.auth().currentUser?.uid
    }
    
    var isInLobby: Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        return (localLobby ?? lobby).players.keys.contains(userId)
    }
    
    var currentLobbyState: Lobby? {
        localLobby ?? lobbyManager.currentLobby ?? lobby
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                MainContentView(
                    currentLobbyState: currentLobbyState,
                    lobby: lobby,
                    isHost: isHost,
                    isInLobby: isInLobby,
                    isJoining: isJoining,
                    onJoin: joinLobby,
                    onStart: startGame
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        handleBack()
                    }
                    .disabled(isLeaving)
                }
            }
            .onAppear { setupLobbyObserver() }
            .onDisappear {
                if !showingGame {
                    lobbyManager.stopObservingLobby()
                }
            }
            .onChange(of: lobbyManager.currentLobbyStatus) { _, newStatus in
                if newStatus == .inProgress {
                    showingGame = true
                } else if newStatus == .completed {
                    // Handle game completion
                    showingGame = false
                    onDismiss()
                    dismiss()
                }
            }
            .onChange(of: lobbyManager.currentLobby) { _, newLobby in
                if let newLobby = newLobby {
                    localLobby = newLobby
                }
            }
            .onChange(of: shouldDismissToRoot) { _, shouldDismiss in
                if shouldDismiss {
                    onDismiss()
                    dismiss()
                }
            }
            .fullScreenCover(isPresented: $showingGame) {
                if let currentLobby = currentLobbyState {
                    GameView(
                        lobby: currentLobby,
                        lobbyManager: lobbyManager,
                        onGameEnd: {
                            shouldDismissToRoot = true
                        }
                    )
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Methods
    private func setupLobbyObserver() {
        localLobby = lobby
        lobbyManager.observeLobby(lobby)
    }
    
    private func handleBack() {
        guard isInLobby else {
            onDismiss()
            dismiss()
            return
        }
        
        isLeaving = true
        Task {
            do {
                try await lobbyManager.leaveLobby(lobby)
                await MainActor.run {
                    onDismiss()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLeaving = false
                }
            }
        }
    }
    
    private func joinLobby() {
        isJoining = true
        Task {
            do {
                try await lobbyManager.joinLobby(lobby)
                if let updatedLobby = lobbyManager.currentLobby {
                    await MainActor.run {
                        localLobby = updatedLobby
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to join lobby: \(error.localizedDescription)"
                    showError = true
                }
            }
            isJoining = false
        }
    }
    
    private func startGame() {
        Task {
            do {
                try await lobbyManager.startGame(lobbyId: lobby.id)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start game: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Subviews
private struct BackgroundView: View {
    var body: some View {
        Image("StoryTalesBackground")
            .resizable()
            .ignoresSafeArea()
    }
}

private struct MainContentView: View {
    let currentLobbyState: Lobby?
    let lobby: Lobby
    let isHost: Bool
    let isInLobby: Bool
    let isJoining: Bool
    let onJoin: () -> Void
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            TitleSection(title: currentLobbyState?.title ?? lobby.title)
            
            PlayerCountSection(
                count: currentLobbyState?.players.count ?? 0,
                maxPlayers: currentLobbyState?.maxPlayers ?? 4
            )
            
            Spacer()
            
            PlayersGridView(
                players: currentLobbyState?.players.values ?? [:].values,
                maxPlayers: currentLobbyState?.maxPlayers ?? 4
            )
            
            Spacer()
            
            ActionButtonsView(
                isHost: isHost,
                isInLobby: isInLobby,
                isJoining: isJoining,
                playerCount: currentLobbyState?.players.count ?? 0,
                maxPlayers: currentLobbyState?.maxPlayers ?? 4,
                onJoin: onJoin,
                onStart: onStart
            )
        }
        .padding(.vertical)
    }
}

private struct TitleSection: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.white)
    }
}

private struct PlayerCountSection: View {
    let count: Int
    let maxPlayers: Int
    
    var body: some View {
        Text("\(count)/\(maxPlayers) Players")
            .font(.headline)
            .foregroundColor(.white.opacity(0.8))
    }
}

private struct PlayersGridView: View {
    let players: Dictionary<String, Player>.Values
    let maxPlayers: Int
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 20)], spacing: 20) {
            ForEach(Array(players), id: \.email) { player in
                PlayerCard(player: player)
            }
            
            ForEach(0..<(maxPlayers - players.count), id: \.self) { _ in
                EmptyPlayerSlot()
            }
        }
        .padding(.horizontal)
    }
}

private struct ActionButtonsView: View {
    let isHost: Bool
    let isInLobby: Bool
    let isJoining: Bool
    let playerCount: Int
    let maxPlayers: Int
    let onJoin: () -> Void
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if isHost {
                Button(action: onStart) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Game")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(playerCount >= 2 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(playerCount < 2)
            } else if !isInLobby {
                Button(action: onJoin) {
                    HStack {
                        Image(systemName: "person.fill.badge.plus")
                        Text(isJoining ? "Joining..." : "Join Lobby")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(playerCount < maxPlayers ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isJoining || playerCount >= maxPlayers)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Helper Views
struct PlayerCard: View {
    let player: Player
    
    var body: some View {
        VStack(spacing: 8) {
            if let imageData = player.imageData {
                Image(base64String: imageData)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
            } else {
                Image(player.avatar)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }
            
            Text(player.username)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyPlayerSlot: View {
    var body: some View {
        VStack {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Empty Slot")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview Provider
#Preview {
    NavigationStack {
        LobbyDetailView(
            lobbyManager: LobbyManager(authManager: AuthManager()),
            lobby: Lobby(
                id: "preview",
                hostId: "host",
                title: "Preview Lobby",
                description: "String",
                maxPlayers: 4,
                status: .waiting,
                gameMode: .timed,
                timerDuration: 60,
                players: [
                    "1": Player(
                        email: "player1@example.com",
                        username: "player1",
                        firstName: "Player",
                        lastName: "One",
                        avatar: "Boy1",
                        joinedAt: Date()
                    ),
                    "2": Player(
                        email: "player2@example.com",
                        username: "player2",
                        firstName: "Player",
                        lastName: "Two",
                        avatar: "Girl1",
                        joinedAt: Date()
                    )
                ]
            ),
            onDismiss: {}
        )
    }
}
