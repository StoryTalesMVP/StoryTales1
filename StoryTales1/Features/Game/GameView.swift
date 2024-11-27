import SwiftUI
import FirebaseAuth
import FirebaseDatabase

// MARK: - Contribution Model
struct Contribution: Identifiable {
    let id = UUID()
    let content: String
    let playerUsername: String
    let playerAvatar: String
}

// MARK: - SubViews
struct GameHeaderView: View {
    let totalGameTime: Int
    let gameMode: Lobby.GameMode
    
    var formattedTotalTime: String {
        let minutes = totalGameTime / 60
        let seconds = totalGameTime % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack {
            Label(formattedTotalTime, systemImage: "clock")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(gameMode == .timed ? "Timed Mode" : "Free Writing")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal)
    }
}

struct StoryContentView: View {
    let title: String
    let contributions: [Contribution]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(contributions) { contribution in
                        ContributionView(contribution: contribution)
                        
                        if contribution.id != contributions.last?.id {
                            Color.clear
                                .frame(height: 6)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .background(Color.gray)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ContributionView: View {
    let contribution: Contribution
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(contribution.playerAvatar)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                
                Text(contribution.playerUsername)
                    .font(.caption)
                    .foregroundColor(.black)
            }
            
            Text(contribution.content)
                .font(.body)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CurrentTurnView: View {
    let currentTurnPlayer: Player?
    let timeRemaining: Int
    let gameMode: Lobby.GameMode
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if let player = currentTurnPlayer {
                    Image(player.avatar)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                }
                Text("Current Turn: \(currentTurnPlayer?.email ?? "Unknown")")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.3))
            .clipShape(Capsule())
            
            if gameMode == .timed {
                Text("\(timeRemaining)s")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(timeRemaining <= 10 ? .red : .white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                    )
            }
        }
    }
}

struct InputSection: View {
    let gameMode: Lobby.GameMode
    @Binding var currentInput: String
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            TextEditor(text: $currentInput)
                .frame(height: 100)
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            if gameMode == .freeform {
                Button(action: onSubmit) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Pass Turn")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(currentInput.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(currentInput.isEmpty)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Main GameView
struct GameView: View {
    @Environment(AuthManager.self) var authManager
    @Environment(\.dismiss) var dismiss
    let lobby: Lobby
    @StateObject var lobbyManager: LobbyManager
    let onGameEnd: () -> Void
    
    @State private var storyContent = ""
    @State private var timeRemaining = 60
    @State private var timer: Timer?
    @State private var gameTimer: Timer?
    @State private var totalGameTime = 0
    @State private var isMyTurn = false
    @State private var showEndGame = false
    @State private var contributions: [Contribution] = []
    @State private var currentInput = ""
    @State private var shouldDismiss = false
    
    private let dbRef = Database.database().reference()
    
    var isHost: Bool {
        lobby.hostId == Auth.auth().currentUser?.uid
    }
    
    var currentTurnPlayer: Player? {
        lobby.players[lobby.story?.currentTurn ?? ""]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Image("StoryTalesBackground")
                    .resizable()
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    GameHeaderView(totalGameTime: totalGameTime, gameMode: lobby.gameMode)
                    
                    StoryContentView(title: lobby.title, contributions: contributions)
                    
                    CurrentTurnView(
                        currentTurnPlayer: currentTurnPlayer,
                        timeRemaining: timeRemaining,
                        gameMode: lobby.gameMode
                    )
                    
                    if isMyTurn {
                        InputSection(
                            gameMode: lobby.gameMode,
                            currentInput: $currentInput,
                            onSubmit: submitTurn
                        )
                    }
                    
                    if isHost {
                        Button(action: { showEndGame = true }) {
                            HStack {
                                Image(systemName: "flag.fill")
                                Text("End Game")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startGameSession()
                observeGameUpdates()
                observeGameStatus()
                startGameTimer()
            }
            .onDisappear {
                timer?.invalidate()
                gameTimer?.invalidate()
                removeObservers()
            }
            .onChange(of: lobby.story?.currentTurn) { _, newTurn in
                checkTurnAndUpdateTimer(newTurn)
            }
            .alert("End Game", isPresented: $showEndGame) {
                Button("Cancel", role: .cancel) { }
                Button("End Game", role: .destructive) {
                    endGame()
                }
            } message: {
                Text("Are you sure you want to end the game?")
            }
            .onChange(of: shouldDismiss) { _, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func startGameSession() {
        if let story = lobby.story {
            storyContent = story.content
            contributions = parseContributions(story.content)
            checkTurnAndUpdateTimer(story.currentTurn)
            
            if lobby.gameMode == .timed {
                timeRemaining = lobby.timerDuration ?? 60
            }
        }
    }
    
    private func startGameTimer() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            totalGameTime += 1
            if isMyTurn {
                Task {
                    try? await dbRef.child("lobbies/\(lobby.id)/story/totalGameTime").setValue(totalGameTime)
                }
            }
        }
    }
    
    private func checkTurnAndUpdateTimer(_ currentTurn: String?) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isMyTurn = currentTurn == userId
        
        if isMyTurn && lobby.gameMode == .timed {
            startTimer()
        } else {
            timer?.invalidate()
            currentInput = ""
        }
    }
    
    private func startTimer() {
        timeRemaining = lobby.timerDuration ?? 60
        timer?.invalidate()
        updateTimeRemaining(timeRemaining)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                if isMyTurn {
                    updateTimeRemaining(timeRemaining)
                }
            } else {
                submitTurn()
            }
        }
    }
    
    private func updateTimeRemaining(_ time: Int) {
        Task {
            try? await lobbyManager.updateTimeRemaining(time, lobbyId: lobby.id)
        }
    }
    
    private func observeGameUpdates() {
        dbRef.child("lobbies").child(lobby.id).child("story").observe(.value) { snapshot in
            guard let storyData = snapshot.value as? [String: Any],
                  let content = storyData["content"] as? String else { return }
            
            DispatchQueue.main.async {
                if let timeRemaining = storyData["timeRemaining"] as? Int {
                    self.timeRemaining = timeRemaining
                }
                
                if let totalTime = storyData["totalGameTime"] as? Int {
                    self.totalGameTime = totalTime
                }
                
                self.storyContent = content
                self.contributions = parseContributions(content)
            }
        }
    }
    
    private func observeGameStatus() {
        dbRef.child("lobbies").child(lobby.id).child("status").observe(.value) { snapshot in
            guard let status = snapshot.value as? String,
                  status == "completed" else { return }
            
            DispatchQueue.main.async {
                self.shouldDismiss = true
                self.onGameEnd()
            }
        }
    }
    
    private func parseContributions(_ content: String) -> [Contribution] {
        let lines = content.components(separatedBy: "\n\n")
        var currentIndex = 0
        var contributions: [Contribution] = []
        let playerIds = lobby.players.sorted {
            $0.value.joinedAt < $1.value.joinedAt
        }.map { $0.key }
        
        for line in lines where !line.isEmpty {
            let playerIndex = currentIndex % playerIds.count
            let playerId = playerIds[playerIndex]
            if let player = lobby.players[playerId] {
                contributions.append(Contribution(
                    content: line,
                    playerUsername: player.username,
                    playerAvatar: player.avatar
                ))
            }
            currentIndex += 1
        }
        
        return contributions
    }
    
    private func removeObservers() {
        dbRef.child("lobbies").child(lobby.id).child("story").removeAllObservers()
        dbRef.child("lobbies").child(lobby.id).child("status").removeAllObservers()
    }
    
    private func submitTurn() {
        guard !currentInput.isEmpty else { return }
        
        timer?.invalidate()
        
        let updatedContent = storyContent.isEmpty ?
            currentInput : "\(storyContent)\n\n\(currentInput)"
        
        Task {
            do {
                try await lobbyManager.updateGameContent(
                    lobbyId: lobby.id,
                    content: updatedContent
                )
                currentInput = ""
            } catch {
                print("Error submitting turn: \(error.localizedDescription)")
            }
        }
    }
    
    private func endGame() {
        Task {
            do {
                if isHost && isMyTurn && !currentInput.isEmpty {
                    let finalContent = storyContent.isEmpty ?
                        currentInput : "\(storyContent)\n\n\(currentInput)"
                    try await lobbyManager.updateGameContent(
                        lobbyId: lobby.id,
                        content: finalContent
                    )
                }
                
                try await lobbyManager.endGame(lobbyId: lobby.id)
            } catch {
                print("Error ending game: \(error.localizedDescription)")
            }
        }
    }
}
