//
//  CreateLobbyView.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import SwiftUI

struct CreateLobbyView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthManager.self) var authManager
    let lobbyManager: LobbyManager
    let onLobbyCreated: (Lobby) -> Void
    
    @State private var lobbyTitle = ""
    @State private var lobbyDescription = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedGameMode: Lobby.GameMode = .timed
    @State private var timerDuration: Double = 60
    
    // Character limits
    private let titleLimit = 50
    private let descriptionLimit = 200
    
    private var isFormValid: Bool {
        !lobbyTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lobbyDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isCreating
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Image
                        Image("StoryBook")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .padding(.top)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Title Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Story Title")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter a captivating title", text: $lobbyTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: lobbyTitle) {
                                        if lobbyTitle.count > titleLimit {
                                            lobbyTitle = String(lobbyTitle.prefix(titleLimit))
                                        }
                                    }
                                
                                Text("\(lobbyTitle.count)/\(titleLimit)")
                                    .font(.caption)
                                    .foregroundColor(lobbyTitle.count >= titleLimit ? .red : .secondary)
                            }
                            
                            // Description Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Story Description")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextEditor(text: $lobbyDescription)
                                    .frame(minHeight: 100)
                                    .padding(4)
                                    .background(Color(UIColor.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                    )
                                    .onChange(of: lobbyDescription) {
                                        if lobbyDescription.count > descriptionLimit {
                                            lobbyDescription = String(lobbyDescription.prefix(descriptionLimit))
                                        }
                                    }
                                
                                Text("\(lobbyDescription.count)/\(descriptionLimit)")
                                    .font(.caption)
                                    .foregroundColor(lobbyDescription.count >= descriptionLimit ? .red : .secondary)
                            }
                            
                            // Game Mode Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Game Mode")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Picker("Game Mode", selection: $selectedGameMode) {
                                    Text("Timed Mode").tag(Lobby.GameMode.timed)
                                    Text("Free Writing").tag(Lobby.GameMode.freeform)
                                }
                                .pickerStyle(.segmented)
                                .padding(.vertical, 4)
                                
                                if selectedGameMode == .timed {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Time per Turn:")
                                                .font(.subheadline)
                                            Text("\(Int(timerDuration))s")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Slider(value: $timerDuration,
                                               in: 10...60,
                                               step: 5)
                                        .tint(.blue)
                                        
                                        Text("Players have between 10-60 seconds to write their part")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                } else {
                                    Text("Players can take their time and pass when ready")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            
                            // Creation Button
                            Button(action: createLobby) {
                                if isCreating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create Story")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(!isFormValid)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 2)
                        .padding()
                    }
                }
            }
            .navigationTitle("Create New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func createLobby() {
        isCreating = true
        
        // Trim whitespace
        let trimmedTitle = lobbyTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = lobbyDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                try await lobbyManager.createLobby(
                    title: trimmedTitle,
                    description: trimmedDescription,
                    gameMode: selectedGameMode,
                    timerDuration: selectedGameMode == .timed ? Int(timerDuration) : nil
                )
                
                await MainActor.run {
                    if let newLobby = lobbyManager.lobbies.first(where: { $0.title == trimmedTitle }) {
                        onLobbyCreated(newLobby)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            isCreating = false
        }
    }
}

// Preview
struct CreateLobbyView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthManager()
        return CreateLobbyView(
            lobbyManager: LobbyManager(authManager: authManager),
            onLobbyCreated: { _ in }
        )
        .environment(authManager)
    }
}
