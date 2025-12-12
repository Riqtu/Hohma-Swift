//
//  ShareRaceToChatView.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import SwiftUI

struct ShareRaceToChatView: View {
    let race: Race
    let onDismiss: () -> Void

    var body: some View {
        ShareToChatView(
            title: "Поделиться скачкой",
            emptyStateMessage: "Создайте чат, чтобы поделиться скачкой",
            messageType: .race,
            itemId: race.id,
            onDismiss: onDismiss
        )
    }
}
