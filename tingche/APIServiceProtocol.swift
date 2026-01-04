// Purpose: Protocol abstraction for APIService to enable dependency injection and testing.
// Author: Achord <achordchan@gmail.com>
import Foundation

protocol APIServiceProtocol {
    func login(username: String, password: String) async throws -> (Bool, String?, String?)
    func getGiftInfoList(token: String, mid: String) async throws -> [APIService.GiftInfoListItem]
    func discoverParkingVoucherGift(token: String, mid: String) async throws -> APIService.GiftInfoListItem
}

extension APIService: APIServiceProtocol {}
