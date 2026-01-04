// Purpose: Account model used across UI, persistence, and network operations.
// Author: Achord <achordchan@gmail.com>
import Foundation

struct AccountInfo: Identifiable, Codable {
    let id: UUID
    var username: String
    var password: String
    var voucherCount: Int
    var isProcessedToday: Bool
    var token: String?
    var bonus: Int
    var uid: String?

    init(id: UUID = UUID(), username: String, password: String, token: String? = nil, voucherCount: Int = 0, isProcessedToday: Bool = false, bonus: Int = 0, uid: String? = nil) {
        self.id = id
        self.username = username
        self.password = password
        self.token = token
        self.voucherCount = voucherCount
        self.isProcessedToday = isProcessedToday
        self.bonus = bonus
        self.uid = uid
    }
}
