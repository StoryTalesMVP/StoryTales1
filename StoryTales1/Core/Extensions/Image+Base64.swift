//
//  Image+Base64.swift
//  StoryTales1
//
//  Created by Allen Odoom on 11/26/24.
//

import SwiftUI

extension Image {
    init(base64String: String) {
        guard let imageData = Data(base64Encoded: base64String),
              let uiImage = UIImage(data: imageData) else {
            self = Image(systemName: "person.circle.fill")
            return
        }
        self = Image(uiImage: uiImage)
    }
}
