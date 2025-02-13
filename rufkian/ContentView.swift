//
//  ContentView.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-02-09.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State var showingCall = false

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                CompanionView()
                
                Spacer()
                
                Button(action: { showingCall = true}) {
                    Label("Call Ai", systemImage: "phone")
                }
                .buttonStyle(.bordered)
                .controlSize(.extraLarge)
                .fullScreenCover(isPresented: $showingCall) {
                    CallView(presentedAsModal: $showingCall)
                        .interactiveDismissDisabled(true)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
