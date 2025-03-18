//
//  rufkianApp.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-02-09.
//

import SwiftUI
import SwiftData

@main
struct rufkianApp: App {
    @StateObject private var router = Router()
    
    init() {
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                EmptyView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .openLogin:
                        LoginView()
                    case .openCompanion:
                        CompanionView()
                    }
                }
            }
            .environmentObject(router)
        }
    }
}
