//
//  LobbyManager.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth

@Observable
class LobbyManager: ObservableObject {
    // MARK: - Properties
    private var ref: DatabaseReference
    private let authManager: AuthManager
    var lobbies: [Lobby] = []
    var currentLobby: Lobby?
    var currentLobbyStatus: Lobby.LobbyStatus?
    var completedStories: [Lobby] = []
    private var statusObserver: DatabaseHandle?
    private var lobbyObserver: DatabaseHandle?
    private var completedStoriesObserver: DatabaseHandle?
    
    // MARK: - Error Types
    enum LobbyError: LocalizedError {
        case userNotAuthenticated
        case noUserProfile
        case lobbyIdGenerationFailed
        case encodingFailed
        case lobbyFull
        case noActiveLobby
        case notHost
        case insufficientPlayers
        case playerNotFound
        case currentPlayerNotFound
        
        var errorDescription: String? {
            switch self {
            case .userNotAuthenticated:
                return "User is not authenticated"
            case .noUserProfile:
                return "User profile not found"
            case .lobbyIdGenerationFailed:
                return "Failed to generate lobby ID"
            case .encodingFailed:
                return "Failed to encode data"
            case .lobbyFull:
                return "Lobby is full"
            case .noActiveLobby:
                return "No active lobby"
            case .notHost:
                return "Only the host can perform this action"
            case .insufficientPlayers:
                return "Need at least 2 players to start"
            case .playerNotFound:
                return "Player not found in lobby"
            case .currentPlayerNotFound:
                return "Cannot determine current player"
            }
        }
    }
    
    // MARK: - Initialization
    init(authManager: AuthManager) {
        self.authManager = authManager
        ref = Database.database().reference()
        startObservingLobbies()
        startObservingCompletedStories()
    }
    
    // MARK: - Observing Active Lobbies
    func startObservingLobbies() {
        ref.child("lobbies").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var newLobbies: [Lobby] = []
            
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let lobbyData = try? JSONSerialization.data(withJSONObject: snapshot.value as Any),
                   let lobby = try? JSONDecoder().decode(Lobby.self, from: lobbyData),
                   lobby.status != .completed {
                    newLobbies.append(lobby)
                    
                    if let currentLobby = self.currentLobby, currentLobby.id == lobby.id {
                        self.currentLobby = lobby
                        self.currentLobbyStatus = lobby.status
                    }
                }
            }
            
            self.lobbies = newLobbies.sorted { $0.title < $1.title }
        }
    }
    
    func stopObservingLobbies() {
        ref.child("lobbies").removeAllObservers()
    }
    
    // MARK: - Observing Completed Stories
    func startObservingCompletedStories() {
        completedStoriesObserver = ref.child("lobbies").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var stories: [Lobby] = []
            
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let lobbyData = try? JSONSerialization.data(withJSONObject: snapshot.value as Any),
                   let lobby = try? JSONDecoder().decode(Lobby.self, from: lobbyData),
                   lobby.status == .completed {
                    stories.append(lobby)
                }
            }
            
            let sortedStories = stories.sorted {
                ($0.story?.lastUpdatedDate ?? Date()) > ($1.story?.lastUpdatedDate ?? Date())
            }
            
            Task { @MainActor in
                self.completedStories = sortedStories
            }
        }
    }
    
    func stopObservingCompletedStories() {
        if let handle = completedStoriesObserver {
            ref.removeObserver(withHandle: handle)
            completedStoriesObserver = nil
        }
    }
    
    // MARK: - Observing a Specific Lobby
    func observeLobby(_ lobby: Lobby) {
        currentLobby = lobby
        currentLobbyStatus = lobby.status
        
        stopObservingLobby()
        
        lobbyObserver = ref.child("lobbies/\(lobby.id)").observe(.value) { [weak self] snapshot in
            guard let self = self,
                  let value = snapshot.value as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: value),
                  let updatedLobby = try? JSONDecoder().decode(Lobby.self, from: data)
            else { return }
            
            Task { @MainActor in
                self.currentLobby = updatedLobby
                self.currentLobbyStatus = updatedLobby.status
                
                if let index = self.lobbies.firstIndex(where: { $0.id == updatedLobby.id }) {
                    self.lobbies[index] = updatedLobby
                }
            }
        }
    }
    
    func stopObservingLobby() {
        if let handle = lobbyObserver {
            ref.removeObserver(withHandle: handle)
            lobbyObserver = nil
        }
        if let handle = statusObserver {
            ref.removeObserver(withHandle: handle)
            statusObserver = nil
        }
        currentLobby = nil
        currentLobbyStatus = nil
    }
    
    // MARK: - Creating, Joining, and Leaving Lobbies
    func createLobby(
        title: String,
        description: String,
        gameMode: Lobby.GameMode,
        timerDuration: Int?
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw LobbyError.userNotAuthenticated
        }
        
        guard let userProfile = authManager.userProfile else {
            throw LobbyError.noUserProfile
        }
        
        let lobbyRef = ref.child("lobbies").childByAutoId()
        guard let lobbyId = lobbyRef.key else {
            throw LobbyError.lobbyIdGenerationFailed
        }
        
        let player = Player(
            email: userProfile.email,
            username: userProfile.username,
            firstName: userProfile.firstName,
            lastName: userProfile.lastName,
            avatar: userProfile.avatar,
            joinedAt: Date(),
            imageData: userProfile.imageData
        )
        
        let lobby = Lobby(
            id: lobbyId,
            hostId: userId,
            title: title,
            description: description,
            maxPlayers: 4,
            status: .waiting,
            gameMode: gameMode,
            timerDuration: timerDuration,
            players: [userId: player]
        )
        
        let data = try JSONEncoder().encode(lobby)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LobbyError.encodingFailed
        }
        
        try await lobbyRef.setValue(dict)
        await MainActor.run {
            self.currentLobby = lobby
        }
    }
    
    func joinLobby(_ lobby: Lobby) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw LobbyError.userNotAuthenticated
        }
        
        guard let userProfile = authManager.userProfile else {
            throw LobbyError.noUserProfile
        }
        
        guard lobby.players.count < lobby.maxPlayers else {
            throw LobbyError.lobbyFull
        }
        
        let player = Player(
            email: userProfile.email,
            username: userProfile.username,
            firstName: userProfile.firstName,
            lastName: userProfile.lastName,
            avatar: userProfile.avatar,
            joinedAt: Date(),
            imageData: userProfile.imageData
        )
        
        let playerData = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(player)
        ) as? [String: Any]
        
        guard let playerData = playerData else {
            throw LobbyError.encodingFailed
        }
        
        try await ref.child("lobbies/\(lobby.id)/players/\(userId)").setValue(playerData)
        await MainActor.run {
            self.observeLobby(lobby)
        }
    }
    
    func leaveLobby(_ lobby: Lobby) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw LobbyError.userNotAuthenticated
        }
        
        if lobby.hostId == userId {
            try await ref.child("lobbies/\(lobby.id)").removeValue()
        } else {
            try await ref.child("lobbies/\(lobby.id)/players/\(userId)").removeValue()
        }
        
        await MainActor.run {
            self.stopObservingLobby()
        }
    }
    
    // MARK: - Game Management
    func startGame(lobbyId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw LobbyError.userNotAuthenticated
        }
        
        guard let lobby = currentLobby else {
            throw LobbyError.noActiveLobby
        }
        
        guard lobby.hostId == userId else {
            throw LobbyError.notHost
        }
        
        guard lobby.players.count >= 2 else {
            throw LobbyError.insufficientPlayers
        }
        
        let storyData: [String: Any] = [
            "content": "",
            "currentTurn": userId,
            "lastUpdated": ServerValue.timestamp(),
            "timeRemaining": lobby.gameMode == .timed ? (lobby.timerDuration ?? 60) : 0,
            "totalGameTime": 0
        ]
        
        let updates: [String: Any] = [
            "status": Lobby.LobbyStatus.inProgress.rawValue,
            "story": storyData
        ]
        
        try await ref.child("lobbies/\(lobbyId)").updateChildValues(updates)
    }
    
    func updateGameContent(lobbyId: String, content: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw LobbyError.userNotAuthenticated
        }
        
        guard let lobby = currentLobby else {
            throw LobbyError.noActiveLobby
        }
        
        let sortedPlayerIds = lobby.players.sorted {
            $0.value.joinedAt < $1.value.joinedAt
        }.map { $0.key }
        
        guard let currentPlayerIndex = sortedPlayerIds.firstIndex(of: userId) else {
            throw LobbyError.currentPlayerNotFound
        }
        
        let nextPlayerIndex = (currentPlayerIndex + 1) % sortedPlayerIds.count
        let nextPlayerId = sortedPlayerIds[nextPlayerIndex]
        
        let updates: [String: Any] = [
            "content": content,
            "currentTurn": nextPlayerId,
            "lastUpdated": ServerValue.timestamp(),
            "timeRemaining": lobby.gameMode == .timed ? (lobby.timerDuration ?? 60) : 0
        ]
        
        try await ref.child("lobbies/\(lobbyId)/story").updateChildValues(updates)
    }
    
    func updateTimeRemaining(_ time: Int, lobbyId: String) async throws {
        try await ref.child("lobbies/\(lobbyId)/story/timeRemaining").setValue(time)
    }
    
    func endGame(lobbyId: String) async throws {
        let updates: [String: Any] = [
            "status": Lobby.LobbyStatus.completed.rawValue
        ]
        
        try await ref.child("lobbies/\(lobbyId)").updateChildValues(updates)
    }
    
    deinit {
        stopObservingLobbies()
        stopObservingLobby()
        stopObservingCompletedStories()
    }
}
