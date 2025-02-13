//
//  CallView.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-02-13.
//

import SwiftUI

struct CallView: View {
    @Binding var presentedAsModal: Bool
    var body: some View {
        VStack {
            Spacer()
            
            Text("HI")
            
            Spacer()
            
            Button(action: { presentedAsModal = false}) {
                Label("End Call", systemImage: "phone.down")
            }
            .buttonStyle(.bordered)
            .controlSize(.extraLarge)
            .buttonBorderShape(.roundedRectangle)
            .tint(.red)
            
            Spacer()
        }
    }
}

#Preview {
    CallView(presentedAsModal: .constant(true))
}

