//
//  ShareWheelToChatView.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import SwiftUI
import Inject

struct ShareWheelToChatView: View {
    @ObserveInjection var inject
    let wheel: WheelWithRelations
    let onDismiss: () -> Void
    
    var body: some View {
        ShareToChatView(
            title: "Поделиться колесом",
            emptyStateMessage: "Создайте чат, чтобы поделиться колесом",
            messageType: .wheel,
            itemId: wheel.id,
            onDismiss: onDismiss
        )
        .enableInjection()
    }
}

