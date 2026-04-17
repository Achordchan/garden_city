// Purpose: Account model used across UI, persistence, and network operations.
// Author: Achord <achordchan@gmail.com>
import Foundation

struct AccountInfo: Identifiable, Codable {
    let id: UUID
    var username: String
    var password: String
    var voucherCount: Int
    var isProcessedToday: Bool
    var isNewToMain: Bool
    var token: String?
    var bonus: Int
    var uid: String?
    var lastCheckinDate: Date?
    var lastCheckinMallID: Int?
    var lastCheckinMallName: String?
    var lastCheckinReward: Int?
    var lastCheckinMessage: String?
    var lastCheckinSucceeded: Bool?
    var lastAutoMallCardRepairDate: Date?

    init(
        id: UUID = UUID(),
        username: String,
        password: String,
        token: String? = nil,
        voucherCount: Int = 0,
        isProcessedToday: Bool = false,
        isNewToMain: Bool = false,
        bonus: Int = 0,
        uid: String? = nil,
        lastCheckinDate: Date? = nil,
        lastCheckinMallID: Int? = nil,
        lastCheckinMallName: String? = nil,
        lastCheckinReward: Int? = nil,
        lastCheckinMessage: String? = nil,
        lastCheckinSucceeded: Bool? = nil,
        lastAutoMallCardRepairDate: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.password = password
        self.token = token
        self.voucherCount = voucherCount
        self.isProcessedToday = isProcessedToday
        self.isNewToMain = isNewToMain
        self.bonus = bonus
        self.uid = uid
        self.lastCheckinDate = lastCheckinDate
        self.lastCheckinMallID = lastCheckinMallID
        self.lastCheckinMallName = lastCheckinMallName
        self.lastCheckinReward = lastCheckinReward
        self.lastCheckinMessage = lastCheckinMessage
        self.lastCheckinSucceeded = lastCheckinSucceeded
        self.lastAutoMallCardRepairDate = lastAutoMallCardRepairDate
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case password
        case voucherCount
        case isProcessedToday
        case isNewToMain
        case token
        case bonus
        case uid
        case lastCheckinDate
        case lastCheckinMallID
        case lastCheckinMallName
        case lastCheckinReward
        case lastCheckinMessage
        case lastCheckinSucceeded
        case lastAutoMallCardRepairDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        password = try container.decode(String.self, forKey: .password)
        voucherCount = try container.decode(Int.self, forKey: .voucherCount)
        isProcessedToday = try container.decode(Bool.self, forKey: .isProcessedToday)
        isNewToMain = try container.decodeIfPresent(Bool.self, forKey: .isNewToMain) ?? false
        token = try container.decodeIfPresent(String.self, forKey: .token)
        bonus = try container.decode(Int.self, forKey: .bonus)
        uid = try container.decodeIfPresent(String.self, forKey: .uid)
        lastCheckinDate = try container.decodeIfPresent(Date.self, forKey: .lastCheckinDate)
        lastCheckinMallID = try container.decodeIfPresent(Int.self, forKey: .lastCheckinMallID)
        lastCheckinMallName = try container.decodeIfPresent(String.self, forKey: .lastCheckinMallName)
        lastCheckinReward = try container.decodeIfPresent(Int.self, forKey: .lastCheckinReward)
        lastCheckinMessage = try container.decodeIfPresent(String.self, forKey: .lastCheckinMessage)
        lastCheckinSucceeded = try container.decodeIfPresent(Bool.self, forKey: .lastCheckinSucceeded)
        lastAutoMallCardRepairDate = try container.decodeIfPresent(Date.self, forKey: .lastAutoMallCardRepairDate)
    }

    var hasCheckedInToday: Bool {
        guard lastCheckinSucceeded == true, let lastCheckinDate else {
            return false
        }
        return Calendar.current.isDateInToday(lastCheckinDate)
    }

    var hasAttemptedAutoMallCardRepairToday: Bool {
        guard let lastAutoMallCardRepairDate else {
            return false
        }
        return Calendar.current.isDateInToday(lastAutoMallCardRepairDate)
    }

    mutating func updateCheckinStatus(
        date: Date = Date(),
        mallID: Int?,
        mallName: String?,
        reward: Int?,
        message: String?,
        succeeded: Bool
    ) {
        lastCheckinDate = date
        lastCheckinMallID = mallID
        lastCheckinMallName = mallName
        lastCheckinReward = reward
        lastCheckinMessage = message
        lastCheckinSucceeded = succeeded
    }

    mutating func resetTodayCheckinStatus() {
        lastCheckinDate = nil
        lastCheckinMallID = nil
        lastCheckinMallName = nil
        lastCheckinReward = nil
        lastCheckinMessage = nil
        lastCheckinSucceeded = false
    }

    mutating func markAutoMallCardRepairAttempt(date: Date = Date()) {
        lastAutoMallCardRepairDate = date
    }
}
