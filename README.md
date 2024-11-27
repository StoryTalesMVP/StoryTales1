# StoryTales - Collaborative Storytelling App

StoryTales is an interactive iOS app that brings people together through collaborative storytelling. Users can join story-writing sessions, contribute their creative ideas, and build narratives together in real-time.

## Features

### Story Creation & Collaboration
- Create story lobbies with customizable settings
- Join existing story sessions (up to 4 players)
- Two writing modes:
  - **Timed Mode**: Each player has a set time to contribute
  - **Free Writing**: Players write at their own pace before passing the turn

### Real-time Interaction
- Live updates as stories develop
- See other players' contributions instantly
- Active player indicators
- Turn-based writing system

### User Profiles
- Customizable profile pictures
- Track personal story contributions
- View writing history
- Browse other users' profiles and stories

### Social Features
- Comment on completed stories
- View other users' contributions
- Track story participation statistics

## Tech Stack

- **Frontend**: SwiftUI
- **Backend**: Firebase
  - Authentication
  - Realtime Database
- **Image Handling**: Base64 encoding for profile pictures
- **State Management**: Observable pattern

## Screenshots(as of 11/27/2024)

<div>
    <img src="https://github.com/user-attachments/assets/5605ce96-ee04-4f13-a21d-de5db03a772d" width="100" alt="IMG_0282">
    <img src="https://github.com/user-attachments/assets/3f7eb804-f5bd-400f-99f7-53815afcf6a4" width="100" alt="IMG_0281">
    <img src="https://github.com/user-attachments/assets/c88ce86e-1590-4482-adcd-d9b15e2f40a5" width="100" alt="IMG_0283">
    <img src="https://github.com/user-attachments/assets/d1f5f4c4-cb17-4952-99e6-42e94740e492" width="100" alt="IMG_0284">
    <img src="https://github.com/user-attachments/assets/39f57fb2-6559-4cbc-a9be-b859ae4d4184" width="100" alt="IMG_0285">
    <img src="https://github.com/user-attachments/assets/b4625146-f5ac-4ea8-82ac-ce411a803837" width="100" alt="IMG_0286">
    <img src="https://github.com/user-attachments/assets/f80ba776-afce-46e9-b2e1-760673ce2753" width="100" alt="IMG_0287">
    <img src="https://github.com/user-attachments/assets/f8ab2ff2-30ca-4975-a2aa-fc37b1cb814b" width="100" alt="IMG_0288">
</div>

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Firebase account

## Installation

1. Clone the repository:
```bash
git clone https://github.com/StoryTalesMVP/StoryTales1.git
```

2. Firebase Setup:
   - Create a new project in [Firebase Console](https://console.firebase.google.com)
   - Add an iOS app to your Firebase project
   - Download `GoogleService-Info.plist`
   - Add it to your Xcode project root

3. Open `StoryTales.xcodeproj` in Xcode

4. Build and run the project

## Contributing

1. Fork the repository
2. Create your feature branch:
```bash
git checkout -b feature/AmazingFeature
```
3. Commit your changes:
```bash
git commit -m 'Add some AmazingFeature'
```
4. Push to the branch:
```bash
git push origin feature/AmazingFeature
```
5. Open a Pull Request

