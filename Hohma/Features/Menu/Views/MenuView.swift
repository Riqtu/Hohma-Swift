//
//  MenuView.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import SwiftUI

struct MenuView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Меню")
                .font(.title)
                .fontWeight(.semibold)

            Text("Здесь будет меню.")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    MenuView()
}
