//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct PassportFloatingButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "book.closed.fill")
                Text("Passport")
                    .fontWeight(.bold)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.adventureOrange)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(radius: 10, y: 5)
        }
        .padding(.bottom, 20)
    }
}
