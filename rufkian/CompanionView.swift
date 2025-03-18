//
//  CompanionView.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-02-13.
//

import SwiftUI
import Foundation
import WebKit

struct CompanionView: View {
    @State var showingCall = false
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                WebView(url: URL(string: "http://localhost:8080")!)
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
        .navigationBarBackButtonHidden(true)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    let cookieSyncManager = CookieSyncManager()
    
    func makeUIView(context: Context) -> WKWebView  {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let group = DispatchGroup()
        group.enter()
        configuration.websiteDataStore.httpCookieStore.setCookiePolicy(.allow) {
            group.leave()
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.configuration.websiteDataStore.httpCookieStore.add(cookieSyncManager)
        webView.load(URLRequest(url: url))
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("update")
    }
}

class CookieSyncManager: NSObject, WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }
}

#Preview {
    CompanionView()
}
