//
//  ShareBattleToChatView.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import SwiftUI
import Inject

struct ShareBattleToChatView: View {
    @ObserveInjection var inject
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
        .enableInjection()
    }
}
