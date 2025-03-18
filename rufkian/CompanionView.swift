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
    @EnvironmentObject var router: Router
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                WebView(url: URL(string: "http://localhost:8080")!, router: router)
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

struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var router: Router
    
    func makeUIView(context: Context) -> WKWebView  {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let group = DispatchGroup()
        
        // SET POLICY
        group.enter()
        configuration.websiteDataStore.httpCookieStore.setCookiePolicy(.allow) {
            group.leave()
        }
        
        // REMOVE OLD COOKIES
        group.enter()
        configuration.websiteDataStore.httpCookieStore.getAllCookies({cookies in
            for cookie in cookies {
                group.enter()
                configuration.websiteDataStore.httpCookieStore.delete(cookie) {
                    group.leave()
                }
            }
            group.leave()
        })
        
        // SET NEW COOKIES
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                group.enter()
                configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
                    group.leave()
                }
            }
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // LOGS
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                print(cookie)
            }
        }
        
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
//    func updateUIView(_ uiView: WKWebView, context: Context) {
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            parent.router.openLogin()
        }
    }
}

#Preview {
    CompanionView()
}
