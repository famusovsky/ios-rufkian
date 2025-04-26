//
//  rufkianApp.swift
//  rufkian
//
//  Created by Aleksei Stepanov on 2025-02-09.
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
