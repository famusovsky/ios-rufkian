//
//  LoginView.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-02-13.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var router: Router
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            HStack {
                Button(action: signIn) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: signUp) {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Response"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // Function to handle sign in
    func signIn() {
        clearCookies()
        guard let url = URL(string: "http://localhost:8080/auth") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["email": email, "password": password]
        print(body)
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        sendRequest(request)
    }

    func signUp() {
        clearCookies()
        guard let url = URL(string: "http://localhost/auth") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        sendRequest(request)
    }

    func sendRequest(_ request: URLRequest) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showingAlert = true
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               let headerFields = httpResponse.allHeaderFields as? [String: String] {
                for cookie in HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: URL(string: "/")!) {
                    if var props = cookie.properties {
                        props.updateValue("http://localhost:8080", forKey: .domain)
                        HTTPCookieStorage.shared.setCookie(HTTPCookie(properties: props)!)
                    }
                }
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                if responseString == "OK" {
                    router.openCompanion()
                    return
                }
                DispatchQueue.main.async {
                    self.alertMessage = "Response: \(responseString)"
                    self.showingAlert = true
                }
            }
        }
        task.resume()
    }
    
    func clearCookies() {
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
}
