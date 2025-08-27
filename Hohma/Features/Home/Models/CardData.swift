//
//  CardData.swift
//  Hohma
//
//  Created by Artem Vydro on 04.08.2025.
//
import SwiftUI

struct CardData: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String?
    let videoName: String?
    let action: (() -> Void)?
}
