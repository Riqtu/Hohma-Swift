import Foundation

struct ProfileUpdateRequest {
    let id: String
    let data: ProfileUpdateData

    var dictionary: [String: Any] {
        return [
            "id": id,
            "data": data.dictionary,
        ]
    }
}

struct ProfileUpdateData {
    let username: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?

    init(
        username: String? = nil, firstName: String? = nil, lastName: String? = nil,
        avatarUrl: String? = nil
    ) {
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
    }

    var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let username = username { dict["username"] = username }
        if let firstName = firstName { dict["firstName"] = firstName }
        if let lastName = lastName { dict["lastName"] = lastName }
        if let avatarUrl = avatarUrl { dict["avatarUrl"] = avatarUrl }
        return dict
    }
}
