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
    init() {
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
    }

    var body: some Scene {
        WindowGroup {
            CompanionView()
        }
    }
}
