//
//  LobbyModels.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/23/24.
//

import Foundation
import FirebaseDatabase

struct Lobby: Identifiable, Codable, Equatable {
    let id: String
    let hostId: String
    let title: String
    let description: String
    let maxPlayers: Int
    let status: LobbyStatus
    let gameMode: GameMode
    let timerDuration: Int?
    var players: [String: Player]
    var story: Story?
    
    enum LobbyStatus: String, Codable {
        case waiting
        case inProgress
        case completed
    }
    
    enum GameMode: String, Codable {
        case timed
        case freeform
    }
    
    // Add this static function to conform to Equatable
    static func == (lhs: Lobby, rhs: Lobby) -> Bool {
        lhs.id == rhs.id &&
        lhs.hostId == rhs.hostId &&
        lhs.title == rhs.title &&
        lhs.description == rhs.description &&
        lhs.maxPlayers == rhs.maxPlayers &&
        lhs.status == rhs.status &&
        lhs.gameMode == rhs.gameMode &&
        lhs.timerDuration == rhs.timerDuration &&
        lhs.players == rhs.players &&
        lhs.story == rhs.story
    }
}

struct Player: Codable, Equatable {
    let email: String
    let username: String
    let firstName: String
    let lastName: String
    let avatar: String
    let joinedAt: Date
    var imageData: String?
}

struct Story: Codable, Equatable {
    var content: String
    var currentTurn: String
    var lastUpdated: TimeInterval
    var timeRemaining: Int
    var totalGameTime: Int
    
    var lastUpdatedDate: Date {
        return Date(timeIntervalSince1970: lastUpdated / 1000)
    }
}
