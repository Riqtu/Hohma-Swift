import Foundation

struct WheelUpdateRequest {
    let id: String
    let name: String?
    let themeId: String?
    let status: WheelStatus?
    let isPrivate: Bool?

    var dictionary: [String: Any] {
        var dict: [String: Any] = ["id": id]

        if let name = name {
            dict["name"] = name
        }
        if let themeId = themeId {
            dict["themeId"] = themeId
        }
        if let status = status {
            dict["status"] = status.rawValue
        }
        if let isPrivate = isPrivate {
            dict["isPrivate"] = isPrivate
        }

        return dict
    }
}
