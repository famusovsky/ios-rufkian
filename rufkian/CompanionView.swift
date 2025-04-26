//
//  CompanionView.swift
//  rufkian
//
//  Created by Aleksei Stepanov on 2025-02-13.
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
                WebView(url: URL(string: "https://www.rufkian.ru")!, showingCall: $showingCall)
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
        webView.customUserAgent = "rufkian"
        webView.load(URLRequest(url: url))
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        var parent: WebView
        var lastFileURL: URL?

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            guard let url = (navigationResponse.response as! HTTPURLResponse).url else {
                decisionHandler(.cancel)
                return
            }

            print(url)
            if url.absoluteString.starts(with: "https://www.rufkian.ru/call") {
                decisionHandler(.cancel)
                parent.showingCall = true
            } else {
                decisionHandler(.allow)
            }
        }
        
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            if let documentDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
                var fileUrl = documentDirectory.appendingPathComponent(suggestedFilename)
                
                var idx = 1
                while FileManager().fileExists(atPath: fileUrl.path) {
                    fileUrl = documentDirectory.appendingPathComponent("\(idx)_\(suggestedFilename)")
                    idx += 1
                }
                
                self.lastFileURL = fileUrl
                
                print(fileUrl)
                print("downloading", suggestedFilename)
                completionHandler(fileUrl)
            }
        }
        
        func downloadDidFinish(_ download: WKDownload) {
            print("downloaded")
        }
        
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            print("\(error.localizedDescription)")
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
