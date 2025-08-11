import Foundation

extension AuthUser {
    var displayName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let name = name {
            return name
        } else {
            return username
        }
    }
}
