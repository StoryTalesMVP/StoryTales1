//
//  LoginView.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import SwiftUI
import PhotosUI

struct LoginView: View {
    @Environment(AuthManager.self) var authManager
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var selectedAvatar = "Boy1"
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showingImagePicker = false
    @State private var showingImageSource = false
    @State private var selectedImage: UIImage?
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    private let avatars = ["Boy1", "Boy2", "Girl1", "Girl2"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Image("StoryTalesBackground")
                    .resizable()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        Image("StoryBook")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                        
                        Text(isSignUp ? "Create Account" : "Welcome Back!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 20) {
                            if isSignUp {
                                // Profile Image Selection
                                VStack(spacing: 12) {
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                            .shadow(radius: 5)
                                    } else {
                                        Image(selectedAvatar)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                            .shadow(radius: 5)
                                    }
                                    
                                    Button(action: { showingImageSource = true }) {
                                        Label("Choose Profile Picture", systemImage: "camera")
                                            .foregroundColor(.blue)
                                    }
                                    
                                    // Default Avatar Selection
                                    if selectedImage == nil {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 15) {
                                                ForEach(avatars, id: \.self) { avatar in
                                                    Image(avatar)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 60, height: 60)
                                                        .clipShape(Circle())
                                                        .overlay(
                                                            Circle()
                                                                .stroke(selectedAvatar == avatar ? Color.blue : Color.clear, lineWidth: 3)
                                                        )
                                                        .onTapGesture {
                                                            selectedAvatar = avatar
                                                            selectedImage = nil
                                                        }
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                                
                                CustomTextField(text: $firstName,
                                             placeholder: "First Name",
                                             systemImage: "person")
                                
                                CustomTextField(text: $lastName,
                                             placeholder: "Last Name",
                                             systemImage: "person")
                                
                                CustomTextField(text: $username,
                                             placeholder: "Username",
                                             systemImage: "person.circle")
                            }
                            
                            CustomTextField(text: $email,
                                         placeholder: "Email",
                                         systemImage: "envelope")
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                            
                            CustomSecureField(text: $password,
                                           placeholder: "Password",
                                           systemImage: "lock")
                        }
                        .padding(.horizontal, 30)
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            Button(action: handleSubmit) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Sign Up" : "Login")
                                        .frame(maxWidth: .infinity)
                                        .fontWeight(.semibold)
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isLoading)
                            
                            Button(action: { isSignUp.toggle() }) {
                                Text(isSignUp ? "Already have an account? Login" : "Don't have an account? Sign Up")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.vertical, 40)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Choose Image Source", isPresented: $showingImageSource) {
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
        }
    }
    
    private func handleSubmit() {
        isLoading = true
        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(
                        email: email,
                        password: password,
                        firstName: firstName,
                        lastName: lastName,
                        username: username,
                        avatar: selectedAvatar,
                        profileImage: selectedImage
                    )
                } else {
                    try await authManager.signIn(email: email, password: password)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views
struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.gray)
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CustomSecureField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.gray)
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
