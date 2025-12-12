//
//  ShareWheelToChatView.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import SwiftUI

struct ShareWheelToChatView: View {
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
    }
}

