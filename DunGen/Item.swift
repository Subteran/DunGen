//
//  Item.swift
//  DunGen
//
//  Created by William Wright on 10/13/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
