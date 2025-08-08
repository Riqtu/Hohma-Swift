//
//  hohmaApp.swift
//  hohma
//
//  Created by Artem Vydro on 17.07.2025.
//

import SwiftUI
import Inject

@main
struct hohmaApp: App {
    
    init() {
        #if DEBUG
        InjectConfiguration.animation = .interactiveSpring()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
            }
        }
    }
}
