//
//  UserProfile.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/25/24.
//

import Foundation
import FirebaseDatabase

struct UserProfile: Codable, Identifiable {
    let userId: String
    var firstName: String
    var lastName: String
    var username: String
    var email: String
    var avatar: String
    var imageData: String?
    
    var id: String { userId }  // Computed property for Identifiable conformance
    
    enum CodingKeys: String, CodingKey {
        case userId
        case firstName
        case lastName
        case username
        case email
        case avatar
        case imageData
    }
}
