//
//  CommentModel.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/26/24.
//

import Foundation
import FirebaseDatabase

struct Comment: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let userAvatar: String
    let imageData: String?
    let content: String
    let timestamp: TimeInterval
    
    var date: Date {
        return Date(timeIntervalSince1970: timestamp / 1000)
    }
}
