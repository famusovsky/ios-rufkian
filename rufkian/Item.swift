//
//  Item.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-02-09.
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
