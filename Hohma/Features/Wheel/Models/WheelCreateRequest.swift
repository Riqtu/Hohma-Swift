import Foundation

struct WheelCreateRequest {
    let name: String
    let themeId: String
    let status: WheelStatus

    var dictionary: [String: Any] {
        return [
            "name": name,
            "themeId": themeId,
            "status": status.rawValue,
        ]
    }
}
