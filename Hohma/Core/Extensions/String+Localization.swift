//
//  String+Localization.swift
//  Hohma
//
//  Created for localization support
//

import Foundation

extension String {
    /// Локализованная строка
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Локализованная строка с аргументами
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}
