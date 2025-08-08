//
//  Date+Decoding.swift,.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

extension JSONDecoder.DateDecodingStrategy {
    static let iso8601withMilliseconds = custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateStr = try container.decode(String.self)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        if let date = formatter.date(from: dateStr) {
            return date
        }
        // Fallback: без миллисекунд
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let date = formatter.date(from: dateStr) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date string does not match format expected by formatter.")
    }
}
