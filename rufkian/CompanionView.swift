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
                WebView(url: URL(string: "http://localhost:8080")!, showingCall: $showingCall)
                Spacer()
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
    @Binding var showingCall: Bool
    
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
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        
        return webView
    }

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

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            guard let url = (navigationResponse.response as! HTTPURLResponse).url else {
                decisionHandler(.cancel)
                return
            }

            print(url)
            if url.absoluteString.starts(with: "https://mistral.ai/") {
                decisionHandler(.cancel)
                parent.showingCall = true
            }
            else {
                decisionHandler(.allow)
            }
        }
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
