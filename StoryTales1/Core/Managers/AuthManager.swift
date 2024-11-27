//
//  AuthManager.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase
import UIKit

@Observable
class AuthManager {
    var user: User?
    let isMocked: Bool = false
    var isSignedIn: Bool = false
    var userProfile: UserProfile?
    var allUsers: [UserProfile] = []
    private var handle: AuthStateDidChangeListenerHandle?
    private let database = Database.database().reference()
    
    var userEmail: String? {
        isMocked ? "kingsley@dog.com" : user?.email
    }
    
    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user
            self.isSignedIn = user != nil
            if let userId = user?.uid {
                Task {
                    await self.fetchUserProfile(userId: userId)
                    self.observeAllUsers()
                }
            } else {
                self.allUsers = []
            }
        }
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func observeAllUsers() {
        database.child("users").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            Task { @MainActor in
                var newUsers: [UserProfile] = []
                
                for child in snapshot.children {
                    if let snapshot = child as? DataSnapshot,
                       let userData = try? JSONSerialization.data(withJSONObject: snapshot.value as Any),
                       let userProfile = try? JSONDecoder().decode(UserProfile.self, from: userData),
                       userProfile.userId != self.user?.uid {
                        newUsers.append(userProfile)
                    }
                }
                
                self.allUsers = newUsers.sorted { $0.username < $1.username }
            }
        }
    }
    
    // MARK: - Profile Image Handling
    func updateProfileImage(_ image: UIImage) async throws {
        guard let userId = user?.uid else {
            throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "AuthManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
        }
        
        let base64String = imageData.base64EncodedString()
        
        await MainActor.run {
            userProfile?.imageData = base64String
        }
        
        var updates: [String: Any] = [
            "users/\(userId)/imageData": base64String
        ]
        
        let lobbiesSnapshot = try await database.child("lobbies").getData()
        
        for case let lobbySnapshot as DataSnapshot in lobbiesSnapshot.children {
            if var lobbyData = lobbySnapshot.value as? [String: Any],
               var players = lobbyData["players"] as? [String: Any],
               players[userId] != nil {
                updates["lobbies/\(lobbySnapshot.key)/players/\(userId)/imageData"] = base64String
            }
        }
        
        if let commentsSnapshot = try? await database.child("storyComments").getData(),
           commentsSnapshot.exists() {
            for case let storySnapshot as DataSnapshot in commentsSnapshot.children {
                for case let commentSnapshot as DataSnapshot in storySnapshot.children {
                    if var commentData = commentSnapshot.value as? [String: Any],
                       let commentUserId = commentData["userId"] as? String,
                       commentUserId == userId {
                        updates["storyComments/\(storySnapshot.key)/\(commentSnapshot.key)/imageData"] = base64String
                    }
                }
            }
        }
        
        try await database.updateChildValues(updates)
    }
    
    // MARK: - Authentication
    func signUp(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        username: String,
        avatar: String,
        profileImage: UIImage? = nil
    ) async throws {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            user = authResult.user
            
            var imageData: String?
            if let image = profileImage {
                guard let jpegData = image.jpegData(compressionQuality: 0.5) else {
                    throw NSError(domain: "AuthManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
                }
                imageData = jpegData.base64EncodedString()
            }
            
            let profile = UserProfile(
                userId: authResult.user.uid,
                firstName: firstName,
                lastName: lastName,
                username: username,
                email: email,
                avatar: avatar,
                imageData: imageData
            )
            
            try await saveUserProfile(profile)
            userProfile = profile
            
        } catch {
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            user = authResult.user
            await fetchUserProfile(userId: authResult.user.uid)
        } catch {
            throw error
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
            userProfile = nil
            allUsers = []
        } catch {
            print(error)
        }
    }
    
    // MARK: - Profile Management
    private func saveUserProfile(_ profile: UserProfile) async throws {
        let data = try JSONEncoder().encode(profile)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        try await database.child("users").child(profile.userId).setValue(dict)
    }
    
    private func fetchUserProfile(userId: String) async {
        do {
            let snapshot = try await database.child("users").child(userId).getData()
            guard let value = snapshot.value as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: value),
                  let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
                return
            }
            
            await MainActor.run {
                self.userProfile = profile
            }
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }
}
