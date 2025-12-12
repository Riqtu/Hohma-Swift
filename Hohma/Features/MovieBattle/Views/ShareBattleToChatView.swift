//
//  ShareBattleToChatView.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import SwiftUI

struct ShareBattleToChatView: View {
    let battle: MovieBattle
    let onDismiss: () -> Void

    var body: some View {
        ShareToChatView(
            title: "Поделиться батлом",
            emptyStateMessage: "Создайте чат, чтобы поделиться батлом",
            messageType: .movieBattle,
            itemId: battle.id,
            onDismiss: onDismiss
        )
    }
}
