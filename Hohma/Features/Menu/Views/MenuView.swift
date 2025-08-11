//
//  MenuView.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import SwiftUI
import Inject

struct MenuView: View {
    @ObserveInjection var inject
    var body: some View {
        VStack(spacing: 20) {
            Text("Меню")
                .font(.title)
                .fontWeight(.semibold)

            Text("Здесь будет меню.")
                .foregroundColor(.secondary)
        }
        .padding()
        .enableInjection()
    }
}

#Preview {
    MenuView()
}
