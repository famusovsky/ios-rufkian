//
//  Router.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-03-18.
//

import SwiftUI

enum Route: Hashable {
    case openLogin
    case openCompanion
}

final class Router: ObservableObject {
    static let shared = Router()
    
    @Published var path = [Route]()
    
    init() {
        openCompanion()
    }
    
    func openLogin() {
        path.removeAll()
        path.append(.openLogin)
    }
    
    func openCompanion() {
        path.removeAll()
        path.append(.openCompanion)
    }
}
