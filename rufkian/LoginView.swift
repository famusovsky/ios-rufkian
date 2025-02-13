//
//  LoginView.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-02-13.
//

import SwiftUI

struct LoginView: View {

    // TODO actually store email and password
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField("enter your email", text: $email)
                .textFieldStyle(.roundedBorder)
            TextField("enter your pasword", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, 30)

            Button {
            } label: {
                Text("Sign Up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
            } label: {
                Text("Log In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(30)
    }
}

#Preview {
    LoginView()
}

