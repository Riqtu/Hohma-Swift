import Foundation

struct WheelCreateRequest {
    let name: String
    let themeId: String
    let status: WheelStatus
    let isPrivate: Bool

    var dictionary: [String: Any] {
        return [
            "name": name,
            "themeId": themeId,
            "status": status.rawValue,
            "isPrivate": isPrivate,
        ]
    }
}
