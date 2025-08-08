//
//  DateFormatting.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

extension Date {
    func formattedString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
