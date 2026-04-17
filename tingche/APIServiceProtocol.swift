// Purpose: Protocol abstraction for APIService to enable dependency injection and testing.
// Author: Achord <achordchan@gmail.com>
import Foundation

protocol APIServiceProtocol: Sendable {
    func login(username: String, password: String) async throws -> (Bool, String?, String?)
    func getGiftInfoList(token: String, mid: String) async throws -> [APIService.GiftInfoListItem]
    func getParkingVoucherGiftCandidates(token: String, mid: String) async throws -> [APIService.GiftInfoListItem]
    func discoverParkingVoucherGift(token: String, mid: String) async throws -> APIService.GiftInfoListItem
    func getCheckinBefore(token: String, mallID: Int) async throws -> APIService.CheckinBeforeResponse
    func getCheckinRuleSummary(token: String, mallID: Int) async throws -> APIService.CheckinRuleSummaryResponse
    func getCheckinDetail(token: String, mallID: Int) async throws -> APIService.CheckinDetailResponse
    func performCheckin(token: String, mallID: Int) async throws -> APIService.CheckinActionResponse
}

extension APIService: APIServiceProtocol {}
