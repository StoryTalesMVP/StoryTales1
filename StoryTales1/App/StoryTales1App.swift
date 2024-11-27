//
//  StoryTales1App.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/20/24.
//

import SwiftUI
import FirebaseCore

@main
struct StoryTales1App: App {
    @State private var authManager: AuthManager
    @State private var showingSplash = true
    
    init() {
        FirebaseApp.configure()
        authManager = AuthManager()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showingSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    showingSplash = false
                                }
                            }
                        }
                } else {
                    if authManager.user != nil {
                        TabView {
                            LobbyListView(authManager: authManager)
                                .tabItem {
                                    Label("Lobbies", systemImage: "person.3")
                                }
                            
                            StoriesListView(authManager: authManager)
                                .tabItem {
                                    Label("Stories", systemImage: "book")
                                }
                            
                            UsersView()
                                .tabItem {
                                    Label("Users", systemImage: "person.2")
                                }
                            
                            ProfileView(authManager: authManager)
                                .tabItem {
                                    Label("Profile", systemImage: "person.circle")
                                }
                        }
                        .environment(authManager)
                    } else {
                        LoginView()
                            .environment(authManager)
                    }
                }
            }
        }
    }
}
