// Purpose: Network API client for login, bonus, voucher count, gift discovery, and voucher exchange.
// Author: Achord <achordchan@gmail.com>
import Foundation
import SwiftUI
import CommonCrypto

// API服务
final class APIService: @unchecked Sendable {
    static let shared = APIService()
    private let baseURL = "https://m-bms.cmsk1979.com/api"
    private let parkingFeeMallID = 11992
    private let parkingFeeParkID = 1256
    private let parkingQueryUUIDKey = "parkingQueryUUID"
    private let miniProgramAppID = "wx0ecc3f8bfd59a0d5"
    private let miniProgramReferer = "https://servicewechat.com/wx0ecc3f8bfd59a0d5/41/page-frame.html"
    private let miniProgramUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.62(0x18003e3a) NetType/WIFI Language/zh_CN"
    @Published var currentToken: String?
    private let debugNetwork = false

    private func numericID(from raw: String) -> String {
        raw.filter { $0.isNumber }
    }

    private func maskedToken(_ token: String) -> String {
        let prefix = String(token.prefix(10))
        return "\(prefix)..."
    }

    private func truncated(_ text: String, limit: Int = 2400) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "\n…(truncated, total \(text.count) chars)"
    }

    private func prettyJSON(_ data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }
        return String(data: data, encoding: .utf8) ?? "(non-utf8 \(data.count) bytes)"
    }

    private func logRequest(label: String, request: URLRequest, body: Data? = nil, tokenToMask: String? = nil) {
        guard debugNetwork else { return }
        let method = request.httpMethod ?? "(nil)"
        let url = request.url?.absoluteString ?? "(nil)"

        var lines: [String] = []

        print("\n===== [REQUEST] \(label) =====")
        lines.append("===== [REQUEST] \(label) =====")
        print("URL: \(url)")
        lines.append("URL: \(url)")
        print("Method: \(method)")
        lines.append("Method: \(method)")

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            let keys = ["Content-Type", "Accept", "Origin", "Referer", "User-Agent", "Cookie"]
            for key in keys {
                if let value = headers[key] {
                    let shown = tokenToMask.map { value.replacingOccurrences(of: $0, with: maskedToken($0)) } ?? value
                    print("Header \(key): \(truncated(shown, limit: 600))")
                    lines.append("Header \(key): \(truncated(shown, limit: 600))")
                }
            }
        }

        if let body {
            var text = prettyJSON(body)
            if let tokenToMask {
                text = text.replacingOccurrences(of: tokenToMask, with: maskedToken(tokenToMask))
            }
            print("Body:\n\(truncated(text))")
            lines.append("Body:\n\(truncated(text))")
        }
        print("===== [REQUEST END] \(label) =====\n")
        lines.append("===== [REQUEST END] \(label) =====")

        Task { @MainActor in
            LogStore.shared.add(category: "NET", lines.joined(separator: "\n"))
        }
    }

    private func logResponse(label: String, response: URLResponse?, data: Data, tokenToMask: String? = nil) {
        guard debugNetwork else { return }
        print("\n===== [RESPONSE] \(label) =====")

        var lines: [String] = []
        lines.append("===== [RESPONSE] \(label) =====")

        if let http = response as? HTTPURLResponse {
            print("StatusCode: \(http.statusCode)")
            lines.append("StatusCode: \(http.statusCode)")
            if let contentType = http.value(forHTTPHeaderField: "Content-Type") {
                print("Content-Type: \(contentType)")
                lines.append("Content-Type: \(contentType)")
            }
        }

        var text = prettyJSON(data)
        if let tokenToMask {
            text = text.replacingOccurrences(of: tokenToMask, with: maskedToken(tokenToMask))
        }
        print("Body:\n\(truncated(text))")
        lines.append("Body:\n\(truncated(text))")
        print("===== [RESPONSE END] \(label) =====\n")
        lines.append("===== [RESPONSE END] \(label) =====")

        Task { @MainActor in
            LogStore.shared.add(category: "NET", lines.joined(separator: "\n"))
        }
    }

    enum APIError: Error, LocalizedError {
        case loginFailed(String)
        case networkError(String)
        case invalidResponse

        var message: String {
            switch self {
            case .loginFailed(let msg): return "登录失败: \(msg)"
            case .networkError(let msg): return "网络错误: \(msg)"
            case .invalidResponse: return "服务器响应无效"
            }
        }

        var errorDescription: String? {
            message
        }
    }

    private func parkingVoucherPriority(for name: String) -> Int {
        if name.contains("白金卡") { return 0 }
        if name.contains("黄金卡") { return 1 }
        if name.contains("2小时") { return 2 }
        if name.contains("1小时") { return 3 }
        return 10
    }

    private func uniqueGiftItems(_ items: [GiftInfoListItem]) -> [GiftInfoListItem] {
        var seen = Set<Int>()
        return items
            .sorted {
                let lhsPriority = parkingVoucherPriority(for: $0.n)
                let rhsPriority = parkingVoucherPriority(for: $1.n)
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                return $0.id < $1.id
            }
            .filter { item in
                seen.insert(item.id).inserted
            }
    }

    private func buildMiniProgramHeader(token: String) -> [String: Any] {
        [
            "Token": token,
            "systemInfo": [
                "miniVersion": "1.0.70",
                "system": "iOS 18.4",
                "model": "iPhone 15 pro max<iPhone16,2>",
                "SDKVersion": "3.10.3",
                "version": "8.0.62"
            ]
        ]
    }

    private func getHomepageMarketingGiftEntries(mid: String) async throws -> [GiftInfoListItem] {
        let sanitizedMid = numericID(from: mid)
        guard !sanitizedMid.isEmpty else {
            throw APIError.networkError("无效的 mid")
        }

        guard let midInt = Int(sanitizedMid) else {
            throw APIError.networkError("无效的 mid")
        }

        let url = URL(string: "https://m-bms.cmsk1979.com/a/liteapp/api/lapp/gethomepage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")

        let requestBody: [String: Any] = [
            "MallID": midInt,
            "Platform": 11,
            "AppId": miniProgramAppID
        ]

        let body = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = body

        logRequest(label: "LiteApp/GetHomepage", request: request, body: body)
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        logResponse(label: "LiteApp/GetHomepage", response: httpResponse, data: data)

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["d"] as? String else {
            throw APIError.invalidResponse
        }

        let pattern = #""ResDesc":"积分换礼>礼品详情>([^"]+)","Url":"https://m-bms\.cmsk1979\.com/v/marketing/gift/detail\?gid=(\d+)&mid=(\d+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let nsPayload = payload as NSString
        let matches = regex.matches(
            in: payload,
            range: NSRange(location: 0, length: nsPayload.length)
        )

        let gifts = matches.compactMap { match -> GiftInfoListItem? in
            guard match.numberOfRanges == 4 else { return nil }
            let name = nsPayload.substring(with: match.range(at: 1))
            let gidString = nsPayload.substring(with: match.range(at: 2))
            let midString = nsPayload.substring(with: match.range(at: 3))
            guard midString == sanitizedMid, let gid = Int(gidString) else { return nil }
            return GiftInfoListItem(id: gid, n: name, source: "首页活动位")
        }

        return uniqueGiftItems(gifts)
    }

    func getGiftInfoList(token: String, mid: String) async throws -> [GiftInfoListItem] {
        let sanitizedMid = numericID(from: mid)
        guard !sanitizedMid.isEmpty else {
            throw APIError.networkError("无效的 mid")
        }

        guard let midInt = Int(sanitizedMid) else {
            throw APIError.networkError("无效的 mid")
        }

        let url = URL(string: "\(baseURL)/gift/giftmanager/GetGiftInfoList")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.62(0x18003e3a) NetType/WIFI Language/zh_CN",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://servicewechat.com/wx0ecc3f8bfd59a0d5/41/page-frame.html", forHTTPHeaderField: "Referer")

        let requestBody = [
            "cid": "",
            "pi": 1,
            "bs": "",
            "mid": midInt,
            "ce": 0,
            "ps": 200,
            "Header": buildMiniProgramHeader(token: token)
        ] as [String : Any]

        let body = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = body

        logRequest(label: "GetGiftInfoList", request: request, body: body, tokenToMask: token)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        logResponse(label: "GetGiftInfoList", response: httpResponse, data: data, tokenToMask: token)

        let response = try JSONDecoder().decode(GiftInfoListResponse.self, from: data)
        guard response.m == 1 else {
            throw APIError.networkError(response.e ?? "礼品列表请求失败")
        }

        return response.d ?? []
    }

    func getParkingVoucherGiftCandidates(token: String, mid: String) async throws -> [GiftInfoListItem] {
        let listCandidates = try await getGiftInfoList(token: token, mid: mid)
            .filter { $0.n.contains("停车券") }

        let homepageCandidates = (try? await getHomepageMarketingGiftEntries(mid: mid))?
            .filter { $0.n.contains("停车券") } ?? []

        return uniqueGiftItems(homepageCandidates + listCandidates)
    }

    func discoverParkingVoucherGift(token: String, mid: String) async throws -> GiftInfoListItem {
        let candidates = try await getParkingVoucherGiftCandidates(token: token, mid: mid)
        guard !candidates.isEmpty else {
            let gifts = try await getGiftInfoList(token: token, mid: mid)
            let sample = gifts.prefix(8).map { $0.n }.joined(separator: "、")
            let sampleText = sample.isEmpty ? "(空)" : sample
            throw APIError.networkError("未在礼品列表中找到“停车券”。礼品数: \(gifts.count)。示例: \(sampleText)")
        }

        if let best = candidates.first(where: { $0.n.contains("小时") }) {
            return best
        }

        return candidates[0]
    }

    struct LoginRequest: Codable {
        let MallID: String
        let Mobile: String
        let SNSType: String
        let OauthID: String?
        let Pwd: String
        let BusinessSourceID: Int
        let DataSource: Int
        let GraphicType: Int
        let GraphicVCode: String
        let Keyword: String
        let LoginType: Int
        let Scene: Int
        let VCode: String
    }

    struct LoginResponseData: Codable {
        let MallID: Int
        let UID: Int
        let Mobile: String?
        let Token: String
        let ProjectType: Int
    }

    struct LoginResponse: Codable {
        let m: Int
        let e: String?
        let d: LoginResponseData?
    }

    struct GetBonusRequest: Codable {
        let MallID: String
        let ISRealBonus: Bool
        let Header: RequestHeader

        struct RequestHeader: Codable {
            let Token: String
        }
    }

    struct BonusResponseData: Codable {
        let ID: Int
        let Bonus: Int
        let TotalBonus: Int
        let Mobile: String
        let UserName: String
    }

    struct BonusResponse: Codable {
        let m: Int
        let d: BonusResponseData?
    }

    struct GetVoucherRequest: Codable {
        let MinID: Int
        let PageSize: Int
        let MallID: String
        let Header: RequestHeader

        struct RequestHeader: Codable {
            let Token: String
        }
    }

    struct VoucherItem: Codable {
        let RuleNo: String
        let Name: String
        let UseState: Int
        let EnableTime: String
        let OverdueTime: String
        let VCode: String
    }

    struct VoucherResponse: Codable {
        let m: Int
        let d: [VoucherItem]?
        let e: String?
    }

    struct GiftInfoListItem: Codable {
        let id: Int
        let n: String
        let source: String?

        init(id: Int, n: String, source: String? = nil) {
            self.id = id
            self.n = n
            self.source = source
        }
    }

    struct GiftInfoListResponse: Codable {
        let m: Int
        let e: String?
        let d: [GiftInfoListItem]?
    }

    struct ExchangeRequest: Codable {
        let mid: String
        let gid: String
        let c: Int
        let s: String
        let cbu: String
        let did: String
        let exp: String?
        let IsSplitOrder: Bool?
        let CardLevel: Int?
        let CardTitle: String?
        let Header: MiniProgramHeader
    }

    struct ExchangeResponse: Codable {
        let oid: Int?
        let OrderNo: String?
        let m: Int
        let e: String?
    }

    struct MiniProgramSystemInfo: Codable {
        let miniVersion: String
        let system: String
        let model: String
        let SDKVersion: String
        let version: String

        static let `default` = MiniProgramSystemInfo(
            miniVersion: "1.0.71",
            system: "iOS 18.4",
            model: "iPhone 15 pro max<iPhone16,2>",
            SDKVersion: "3.12.1",
            version: "8.0.65"
        )
    }

    struct MiniProgramHeader: Codable {
        let Token: String
        let systemInfo: MiniProgramSystemInfo
    }

    struct TokenHeader: Codable {
        let Token: String
    }

    struct GiftInfoDetailRequest: Codable {
        let mid: String
        let gid: String
        let m: String
        let did: String
        let Header: MiniProgramHeader
    }

    private struct GiftExchangeContext {
        let discountID: String
    }

    struct ParkingAddUUIDInfoRequest: Codable {
        let MallID: Int
        let Header: MiniProgramHeader
        let UUID: String
    }

    struct ParkingFeeInitRequest: Codable {
        let UID: String
        let MallID: Int
        let ParkID: Int
        let Header: MiniProgramHeader
        let IsVerifyWaitPay: Bool
        let PlateNo: String
        let UUID: String
        let Barcode: String
    }

    struct ParkingFeeV3Request: Codable {
        let MallID: Int
        let Header: TokenHeader
        let PlateNo: String
        let ParkID: Int
    }

    struct ParkingCommonResponse<T: Codable>: Codable {
        let m: Int
        let e: String?
        let d: T?
    }

    struct ParkingFeeInitResponseData: Codable {
        let MallName: String?
        let ParkName: String?
        let PlateNo: String?
        let EntryTime: String?
        let ParkingMinutes: Int?
        let ParkingTotalFee: Double?
        let NeedPayAmount: Double?
        let PaidAmount: Double?
        let FreeAmount: Double?
        let FeeId: String?
        let IsUseRights: Bool?
        let IsShowParkZeroPay: Bool?
        let OfflineDeduction: String?
        let Ext: String?
    }

    struct ParkingFeeV3ResponseData: Codable {
        let ParkName: String?
        let PlateNo: String?
        let EntryTime: String?
        let ParkingMinutes: Int?
        let ParkingTotalFee: Double?
        let NeedPayAmount: Double?
        let PaidAmount: Double?
        let FreeAmount: Double?
        let FeeId: String?
    }

    struct ParkingFeeQueryResult: Codable {
        let plateNo: String
        let mallName: String
        let parkName: String
        let entryTime: String
        let parkingMinutes: Int
        let parkingTotalFee: Double
        let needPayAmount: Double
        let paidAmount: Double
        let freeAmount: Double
        let feeId: String
        let memberRightsSummary: String?
    }

    struct CheckinBeforeRequest: Codable {
        let MallId: Int
        let IsCheckMemberCard: Bool
        let Header: MiniProgramHeader
    }

    struct CheckinBeforeResponseData: Codable {
        let IsCheckIn: Bool?
        let IsCheckInForGroup: Bool?
        let IsOpenCheckin: Bool?
        let IsOpenCheckinForGroup: Bool?
        let GroupTips: String?
        let MallID: Int?
        let MallName: String?
        let GroupID: Int?
        let GroupName: String?
        let IsOpenMemberCard: Bool?
        let IsOpenCheckinForWecom: Bool?
        let IsFollowedUserForWecom: Bool?
        let IsOpenCheckinForPosition: Bool?
        let PositionAreaLimit: Double?
    }

    struct CheckinBeforeResponse: Codable {
        let m: Int
        let e: String?
        let d: CheckinBeforeResponseData?
    }

    struct CheckinRuleSummaryRequest: Codable {
        let MallId: Int
        let Header: MiniProgramHeader
    }

    struct CheckinRewardRule: Codable {
        let RewardTitle: String?
        let RewardSummary: String?
        let RewardContent: String?
        let Num: String?
        let StartDay: Int?
        let EndDay: Int?
        let RewardType: Int?
        let IsPerDay: Bool?
    }

    struct CheckinRuleSummaryResponseData: Codable {
        let Name: String?
        let EffectTime: String?
        let EffectEndTime: String?
        let CheckinRewardRuleType: Int?
        let IsOpenCheckinForPosition: Bool?
        let CheckinRuleDescribe: String?
        let RuleList: [CheckinRewardRule]?
    }

    struct CheckinRuleSummaryResponse: Codable {
        let m: Int
        let e: String?
        let d: CheckinRuleSummaryResponseData?
    }

    struct CheckinActionRequest: Codable {
        let MallID: Int
        let Header: MiniProgramHeader
    }

    struct CheckinActionResponseData: Codable {
        let Title: String?
        let Notice: String?
        let Msg: String?
        let IsCheckIn: Bool?
        let Content: String?
        let RewardType: Int?
        let IsGiveSucess: Bool?
        let Desc: String?
    }

    struct CheckinActionResponse: Codable {
        let m: Int
        let e: String?
        let d: CheckinActionResponseData?
    }

    struct CheckinDetailRequest: Codable {
        let MallID: Int
        let Header: MiniProgramHeader
    }

    struct CheckinDetailResponseData: Codable {
        let StartTime: String?
        let EndTime: String?
        let ContinueDay: Int?
        let CheckinBonusSum: Double?
    }

    struct CheckinDetailResponse: Codable {
        let m: Int
        let e: String?
        let d: CheckinDetailResponseData?
    }

    struct ParkingDiscountQueryRequest: Codable {
        let Data: String
        let Channel: Int
        let Header: MiniProgramHeader
    }

    struct ParkingDiscountQueryPayload: Codable {
        let MallID: Int
        let BusiType: Int
        let BusiID: Int
        let NeedPayAmount: Double
        let ParkingMinutes: Int
        let ExtendFields: String
        let Platform: Int
    }

    struct ParkingDiscountExtendFields: Codable {
        let PlateNo: String
        let Barcode: String
        let FeeId: String
        let UUID: String
        let HasFirstDis: Bool
        let Ext: String
    }

    struct ParkingDiscountQueryResponseData: Codable {
        let RightsRuleModelList: [ParkingDiscountRule]?
    }

    struct ParkingDiscountRule: Codable {
        let RuleName: String?
        let IsShow: Bool?
        let Status: Bool?
        let RightsList: [ParkingDiscountRight]?
    }

    struct ParkingDiscountRight: Codable {
        let RightsName: String?
        let Amount: Double?
        let Minutes: Double?
    }

    private func cachedParkingQueryUUID() -> String {
        if let cached = UserDefaults.standard.string(forKey: parkingQueryUUIDKey), !cached.isEmpty {
            return cached
        }
        let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(generated, forKey: parkingQueryUUIDKey)
        return generated
    }

    private func registerParkingQueryUUID(token: String, uuid: String) async {
        let url = URL(string: "\(baseURL)/park/UUIDInfo/AddUuidInfo")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")

        let requestBody = ParkingAddUUIDInfoRequest(
            MallID: parkingFeeMallID,
            Header: MiniProgramHeader(Token: token, systemInfo: .default),
            UUID: uuid
        )
        guard let body = try? JSONEncoder().encode(requestBody) else {
            print("AddUuidInfo 请求编码失败")
            return
        }

        request.httpBody = body
        logRequest(label: "AddUuidInfo", request: request, body: body, tokenToMask: token)

        do {
            let (data, httpResponse) = try await URLSession.shared.data(for: request)
            logResponse(label: "AddUuidInfo", response: httpResponse, data: data, tokenToMask: token)
            let response = try JSONDecoder().decode(ParkingCommonResponse<Int>.self, from: data)
            if response.m != 1 {
                print("AddUuidInfo 失败：\(response.e ?? "未知错误")")
            }
        } catch {
            print("AddUuidInfo 调用失败：\(error.localizedDescription)")
        }
    }

    private func encryptParkingDiscountPayload(_ payload: ParkingDiscountQueryPayload) throws -> String {
        let plainData = try JSONEncoder().encode(payload)
        let keyData = Data("XuAE0a9d7XHDbaV7".utf8)
        let ivData = Data(repeating: 0, count: kCCBlockSizeAES128)

        var outputData = Data(count: plainData.count + kCCBlockSizeAES128)
        let outputCapacity = outputData.count
        var outputLength: size_t = 0

        let status = outputData.withUnsafeMutableBytes { outputBytes in
            plainData.withUnsafeBytes { plainBytes in
                keyData.withUnsafeBytes { keyBytes in
                    ivData.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            keyData.count,
                            ivBytes.baseAddress,
                            plainBytes.baseAddress,
                            plainData.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw APIError.networkError("停车权益数据加密失败")
        }

        outputData.removeSubrange(outputLength..<outputData.count)
        return outputData.base64EncodedString()
    }

    private func summarizeMemberRights(from rules: [ParkingDiscountRule]?) -> String? {
        guard let rules, !rules.isEmpty else { return nil }

        let prioritizedRules = rules.filter { rule in
            (rule.IsShow ?? true) && (rule.Status ?? false) && (rule.RuleName ?? "").contains("会员")
        }

        let fallbackRules = rules.filter { rule in
            (rule.IsShow ?? true) && (rule.Status ?? false) && !(rule.RuleName ?? "").contains("商场停车券")
        }

        let sourceRules = prioritizedRules.isEmpty ? fallbackRules : prioritizedRules
        guard !sourceRules.isEmpty else { return nil }

        let summaries = sourceRules.compactMap { rule -> String? in
            let rights = (rule.RightsList ?? []).compactMap { item -> String? in
                let name = item.RightsName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return name.isEmpty ? nil : name
            }

            guard !rights.isEmpty else { return nil }

            let uniqueRights = Array(NSOrderedSet(array: rights)) as? [String] ?? rights
            let ruleName = rule.RuleName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if ruleName.isEmpty {
                return uniqueRights.joined(separator: "、")
            }
            return "\(ruleName)：\(uniqueRights.joined(separator: "、"))"
        }

        guard !summaries.isEmpty else { return nil }
        return summaries.joined(separator: "；")
    }

    private func fetchParkingDiscountSummary(token: String, initData: ParkingFeeInitResponseData, plateNo: String, uuid: String) async -> String? {
        guard (initData.IsShowParkZeroPay ?? false) || (initData.NeedPayAmount ?? 0) > 0 else {
            return nil
        }

        let extendFields = ParkingDiscountExtendFields(
            PlateNo: plateNo,
            Barcode: "",
            FeeId: initData.FeeId ?? "",
            UUID: uuid,
            HasFirstDis: (initData.FreeAmount ?? 0) > 0,
            Ext: initData.Ext ?? ""
        )

        guard let extendFieldsData = try? JSONEncoder().encode(extendFields),
              let extendFieldsText = String(data: extendFieldsData, encoding: .utf8) else {
            print("QueryEn ExtendFields 编码失败")
            return nil
        }

        let payload = ParkingDiscountQueryPayload(
            MallID: parkingFeeMallID,
            BusiType: 0,
            BusiID: parkingFeeParkID,
            NeedPayAmount: initData.NeedPayAmount ?? 0,
            ParkingMinutes: initData.ParkingMinutes ?? 0,
            ExtendFields: extendFieldsText,
            Platform: 1
        )

        let encryptedData: String
        do {
            encryptedData = try encryptParkingDiscountPayload(payload)
        } catch {
            print("QueryEn 加密失败：\(error.localizedDescription)")
            return nil
        }

        let url = URL(string: "\(baseURL)/discount/DiscountCore/QueryEn")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")

        let requestBody = ParkingDiscountQueryRequest(
            Data: encryptedData,
            Channel: 1,
            Header: MiniProgramHeader(Token: token, systemInfo: .default)
        )

        guard let body = try? JSONEncoder().encode(requestBody) else {
            print("QueryEn 请求编码失败")
            return nil
        }

        request.httpBody = body
        logRequest(label: "DiscountCore/QueryEn", request: request, body: body, tokenToMask: token)

        do {
            let (data, httpResponse) = try await URLSession.shared.data(for: request)
            logResponse(label: "DiscountCore/QueryEn", response: httpResponse, data: data, tokenToMask: token)
            let response = try JSONDecoder().decode(ParkingCommonResponse<ParkingDiscountQueryResponseData>.self, from: data)
            guard response.m == 1 else {
                print("QueryEn 返回失败：\(response.e ?? "未知错误")")
                return nil
            }
            return summarizeMemberRights(from: response.d?.RightsRuleModelList)
        } catch {
            print("QueryEn 调用失败：\(error.localizedDescription)")
            return nil
        }
    }

    private func fetchParkingFeeInit(token: String, uid: String, plateNo: String, uuid: String) async throws -> ParkingFeeInitResponseData? {
        let url = URL(string: "\(baseURL)/park/ParkFee/GetParkFeeInit")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")

        let requestBody = ParkingFeeInitRequest(
            UID: uid,
            MallID: parkingFeeMallID,
            ParkID: parkingFeeParkID,
            Header: MiniProgramHeader(Token: token, systemInfo: .default),
            IsVerifyWaitPay: true,
            PlateNo: plateNo,
            UUID: uuid,
            Barcode: ""
        )
        let body = try JSONEncoder().encode(requestBody)
        request.httpBody = body

        logRequest(label: "GetParkFeeInit", request: request, body: body, tokenToMask: token)

        do {
            let (data, httpResponse) = try await URLSession.shared.data(for: request)
            logResponse(label: "GetParkFeeInit", response: httpResponse, data: data, tokenToMask: token)
            let response = try JSONDecoder().decode(ParkingCommonResponse<ParkingFeeInitResponseData>.self, from: data)
            if response.m != 1 {
                print("GetParkFeeInit 返回失败：\(response.e ?? "未知错误")")
                return nil
            }
            return response.d
        } catch {
            print("GetParkFeeInit 调用失败：\(error.localizedDescription)")
            return nil
        }
    }

    private func fetchParkingFeeV3(token: String, plateNo: String) async throws -> ParkingFeeV3ResponseData {
        let url = URL(string: "\(baseURL)/park/ParkFee/GetParkFeeV3")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")

        let requestBody = ParkingFeeV3Request(
            MallID: parkingFeeMallID,
            Header: TokenHeader(Token: token),
            PlateNo: plateNo,
            ParkID: parkingFeeParkID
        )
        let body = try JSONEncoder().encode(requestBody)
        request.httpBody = body

        logRequest(label: "GetParkFeeV3", request: request, body: body, tokenToMask: token)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        logResponse(label: "GetParkFeeV3", response: httpResponse, data: data, tokenToMask: token)

        let response = try JSONDecoder().decode(ParkingCommonResponse<ParkingFeeV3ResponseData>.self, from: data)
        guard response.m == 1, let payload = response.d else {
            throw APIError.networkError(response.e ?? "查费失败")
        }
        return payload
    }

    func queryParkingFee(token: String, uid: String, plateNo: String) async throws -> ParkingFeeQueryResult {
        let trimmedPlate = plateNo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPlate.isEmpty else {
            throw APIError.networkError("请先选择车牌号")
        }

        let queryUUID = cachedParkingQueryUUID()
        await registerParkingQueryUUID(token: token, uuid: queryUUID)

        let initData = try await fetchParkingFeeInit(token: token, uid: uid, plateNo: trimmedPlate, uuid: queryUUID)
        let v3Data = try await fetchParkingFeeV3(token: token, plateNo: trimmedPlate)
        let resolvedMemberRightsSummary: String?
        if let initData {
            resolvedMemberRightsSummary = await fetchParkingDiscountSummary(
                token: token,
                initData: initData,
                plateNo: trimmedPlate,
                uuid: queryUUID
            )
        } else {
            resolvedMemberRightsSummary = nil
        }

        return ParkingFeeQueryResult(
            plateNo: v3Data.PlateNo ?? initData?.PlateNo ?? trimmedPlate,
            mallName: initData?.MallName ?? "",
            parkName: v3Data.ParkName ?? initData?.ParkName ?? "",
            entryTime: v3Data.EntryTime ?? initData?.EntryTime ?? "",
            parkingMinutes: v3Data.ParkingMinutes ?? initData?.ParkingMinutes ?? 0,
            parkingTotalFee: v3Data.ParkingTotalFee ?? initData?.ParkingTotalFee ?? 0,
            needPayAmount: v3Data.NeedPayAmount ?? initData?.NeedPayAmount ?? 0,
            paidAmount: v3Data.PaidAmount ?? initData?.PaidAmount ?? 0,
            freeAmount: v3Data.FreeAmount ?? initData?.FreeAmount ?? 0,
            feeId: v3Data.FeeId ?? initData?.FeeId ?? "",
            memberRightsSummary: resolvedMemberRightsSummary
        )
    }

    private func makeMiniProgramRequest(path: String) -> URLRequest {
        let url = URL(string: "\(baseURL)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func performMiniProgramRequest<Body: Encodable, Response: Decodable>(
        path: String,
        label: String,
        body: Body,
        tokenToMask: String? = nil
    ) async throws -> Response {
        var request = makeMiniProgramRequest(path: path)
        let encodedBody = try JSONEncoder().encode(body)
        request.httpBody = encodedBody

        logRequest(label: label, request: request, body: encodedBody, tokenToMask: tokenToMask)
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        logResponse(label: label, response: httpResponse, data: data, tokenToMask: tokenToMask)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func getCheckinBefore(token: String, mallID: Int) async throws -> CheckinBeforeResponse {
        try await performMiniProgramRequest(
            path: "user/user/CheckinBefore",
            label: "CheckinBefore",
            body: CheckinBeforeRequest(
                MallId: mallID,
                IsCheckMemberCard: true,
                Header: MiniProgramHeader(Token: token, systemInfo: .default)
            ),
            tokenToMask: token
        )
    }

    func getCheckinRuleSummary(token: String, mallID: Int) async throws -> CheckinRuleSummaryResponse {
        try await performMiniProgramRequest(
            path: "user/User/GetCheckinRuleSummary",
            label: "GetCheckinRuleSummary",
            body: CheckinRuleSummaryRequest(
                MallId: mallID,
                Header: MiniProgramHeader(Token: token, systemInfo: .default)
            ),
            tokenToMask: token
        )
    }

    func performCheckin(token: String, mallID: Int) async throws -> CheckinActionResponse {
        try await performMiniProgramRequest(
            path: "user/User/CheckinV2",
            label: "CheckinV2",
            body: CheckinActionRequest(
                MallID: mallID,
                Header: MiniProgramHeader(Token: token, systemInfo: .default)
            ),
            tokenToMask: token
        )
    }

    func getCheckinDetail(token: String, mallID: Int) async throws -> CheckinDetailResponse {
        try await performMiniProgramRequest(
            path: "user/User/GetCheckinDetail",
            label: "GetCheckinDetail",
            body: CheckinDetailRequest(
                MallID: mallID,
                Header: MiniProgramHeader(Token: token, systemInfo: .default)
            ),
            tokenToMask: token
        )
    }

    private func anyString(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func anyBool(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes"].contains(normalized) { return true }
            if ["0", "false", "no"].contains(normalized) { return false }
            return nil
        default:
            return nil
        }
    }

    private func anyInt(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func resolveDiscountID(
        from item: [String: Any]?
    ) -> String {
        guard let item else { return "" }
        guard let raw = anyString(item["DiscountID"]) else { return "" }
        return raw == "0" ? "" : raw
    }

    private func resolvePreferredDiscountID(
        discountPrices: [[String: Any]],
        cardLevel: Int?,
        cardTitle: String?
    ) -> String? {
        let trimmedTitle = cardTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasOverride = cardLevel != nil || !trimmedTitle.isEmpty

        for item in discountPrices {
            let isOpen = anyBool(item["IsOpen"]) ?? true
            if !hasOverride, !isOpen {
                continue
            }

            if let cardLevel,
               let itemLevel = anyInt(item["CardLevel"]),
               itemLevel == cardLevel {
                let discountID = resolveDiscountID(from: item)
                if !discountID.isEmpty {
                    return discountID
                }
            }

            if !trimmedTitle.isEmpty {
                let itemName = anyString(item["Name"]) ?? ""
                let itemTitle = anyString(item["CardTitle"]) ?? ""
                if itemName.contains(trimmedTitle) || itemTitle.contains(trimmedTitle) {
                    let discountID = resolveDiscountID(from: item)
                    if !discountID.isEmpty {
                        return discountID
                    }
                }
            }
        }

        return nil
    }

    private func buildGiftExchangeRestrictionMessage(detail: [String: Any]) -> String {
        let allowedCards = (detail["mtl"] as? [[String: Any]] ?? [])
            .compactMap { anyString($0["Name"]) }

        if !allowedCards.isEmpty {
            return "当前账号卡等级不支持兑换，允许等级：\(allowedCards.joined(separator: "、"))"
        }

        if let vipCardName = anyString(detail["VipCardName"]) {
            return "当前账号卡等级不支持兑换，需要：\(vipCardName)"
        }

        return "当前账号暂不满足该停车券的兑换条件"
    }

    private func matchesMembershipOverride(
        detail: [String: Any],
        cardLevel: Int?,
        cardTitle: String?
    ) -> Bool {
        let trimmedTitle = cardTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mallCardTypes = detail["mtl"] as? [[String: Any]] ?? []

        for item in mallCardTypes {
            if let cardLevel {
                let itemLevel = anyInt(item["ID"]) ?? anyInt(item["CardLevel"])
                if itemLevel == cardLevel {
                    return true
                }
            }

            if !trimmedTitle.isEmpty {
                let itemName = anyString(item["Name"]) ?? ""
                let itemTitle = anyString(item["CardTitle"]) ?? ""
                if itemName.contains(trimmedTitle) || itemTitle.contains(trimmedTitle) {
                    return true
                }
            }
        }

        if !trimmedTitle.isEmpty,
           let vipCardName = anyString(detail["VipCardName"]),
           vipCardName.contains(trimmedTitle) {
            return true
        }

        return false
    }

    private func resolveMarketingParkingVoucherGift(
        mid: String,
        cardLevel: Int?,
        cardTitle: String?
    ) async throws -> GiftInfoListItem? {
        let trimmedTitle = cardTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let marketingCandidates = try await getHomepageMarketingGiftEntries(mid: mid)
            .filter { $0.n.contains("停车券") }

        if let cardLevel {
            if cardLevel == 8100,
               let candidate = marketingCandidates.first(where: { $0.n.contains("白金卡") }) {
                return candidate
            }

            if cardLevel == 8099,
               let candidate = marketingCandidates.first(where: { $0.n.contains("黄金卡") }) {
                return candidate
            }
        }

        if !trimmedTitle.isEmpty,
           let candidate = marketingCandidates.first(where: { $0.n.contains(trimmedTitle) }) {
            return candidate
        }

        return nil
    }

    private func resolveExchangeGiftID(
        mid: String,
        gid: String,
        cardLevel: Int?,
        cardTitle: String?
    ) async throws -> String {
        let sanitizedGID = numericID(from: gid)
        guard !sanitizedGID.isEmpty else {
            throw APIError.networkError("无效的 gid")
        }

        guard let memberParkingVoucher = try await resolveMarketingParkingVoucherGift(
            mid: mid,
            cardLevel: cardLevel,
            cardTitle: cardTitle
        ) else {
            return sanitizedGID
        }

        let memberGID = String(memberParkingVoucher.id)
        if sanitizedGID == memberGID {
            return sanitizedGID
        }

        let defaultParkingVoucherGIDs: Set<String> = ["1007561", "1007794"]
        if defaultParkingVoucherGIDs.contains(sanitizedGID) {
            print("检测到会员停车券场景，自动将 gid 从 \(sanitizedGID) 切换为 \(memberGID)")
            return memberGID
        }

        return sanitizedGID
    }

    private func resolveGiftExchangeContext(
        token: String,
        uid: String,
        mid: String,
        gid: String,
        cardLevel: Int?,
        cardTitle: String?
    ) async throws -> GiftExchangeContext {
        let url = URL(string: "\(baseURL)/gift/giftmanager/GetGiftInfoDetail")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")

        let requestBody = GiftInfoDetailRequest(
            mid: mid,
            gid: gid,
            m: uid,
            did: "",
            Header: MiniProgramHeader(Token: token, systemInfo: .default)
        )
        let body = try JSONEncoder().encode(requestBody)
        request.httpBody = body

        logRequest(label: "GetGiftInfoDetail", request: request, body: body, tokenToMask: token)
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        logResponse(label: "GetGiftInfoDetail", response: httpResponse, data: data, tokenToMask: token)

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let resultCode = anyInt(object["m"]) ?? 0
        guard resultCode == 1 else {
            throw APIError.networkError(anyString(object["e"]) ?? "获取礼品详情失败")
        }

        guard let detail = object["d"] as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let trimmedTitle = cardTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasMembershipOverride = cardLevel != nil || !trimmedTitle.isEmpty
        let canExchange = anyBool(detail["CanExchange"]) ?? true
        let discountPrices = detail["DiscountPrices"] as? [[String: Any]] ?? []
        let selectedDiscount = detail["DiscountPrice"] as? [String: Any]
        let preferredDiscountID = resolvePreferredDiscountID(
            discountPrices: discountPrices,
            cardLevel: cardLevel,
            cardTitle: cardTitle
        )
        let resolvedDiscountID = preferredDiscountID ?? resolveDiscountID(from: selectedDiscount)
        let membershipMatched = matchesMembershipOverride(
            detail: detail,
            cardLevel: cardLevel,
            cardTitle: cardTitle
        )

        if !canExchange && !hasMembershipOverride {
            throw APIError.networkError(buildGiftExchangeRestrictionMessage(detail: detail))
        }

        if !canExchange && hasMembershipOverride && resolvedDiscountID.isEmpty && !membershipMatched {
            throw APIError.networkError("当前账号默认不可兑换，且未能根据 CardLevel/CardTitle 匹配到目标会员档位")
        }

        print("礼品详情解析成功，gid=\(gid)，did=\(resolvedDiscountID.isEmpty ? "(empty)" : resolvedDiscountID)")
        return GiftExchangeContext(discountID: resolvedDiscountID)
    }

    func login(username: String, password: String) async throws -> (Bool, String?, String?) {
        let url = URL(string: "\(baseURL)/passport/v2/user/Login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        // 设置必要的Cookie
        let cookies = [
            "_uuid=768ccf7d4c29df0ba4ac9267aedf1a83",
            "selectMallId=11031",
            "_user_checkin_group=0",
            "_mid=11992",
            "_bussinessSrc=%7B%22BusinessSourceID%22%3A2%7D"
        ].joined(separator: "; ")
        request.setValue(cookies, forHTTPHeaderField: "Cookie")

        let loginData = LoginRequest(
            MallID: "11992",
            Mobile: username,
            SNSType: "",
            OauthID: nil,
            Pwd: password,
            BusinessSourceID: 2,
            DataSource: 3,
            GraphicType: 2,
            GraphicVCode: "",
            Keyword: "8cc0d272bfde4e3aa5dfa3b27fc503d0",
            LoginType: 1,
            Scene: 4,
            VCode: ""
        )

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(loginData)

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(LoginResponse.self, from: data)

            if response.m == 1 && response.d != nil {
                self.currentToken = response.d?.Token
                return (true, response.d?.Token, String(response.d?.UID ?? 0))
            }

            let errorMessage = response.e ?? "未知错误"
            throw APIError.loginFailed(errorMessage)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }

    func getBonus(token: String) async throws -> Int {
        try await getBonus(token: token, mallID: "11992")
    }

    func getBonus(token: String, mallID: String) async throws -> Int {
        print("开始查询积分，使用token: \(String(token.prefix(10)))... mallID: \(mallID)")
        let url = URL(string: "\(baseURL)/gift/giftmanager/GetMallCard")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        print("正在构建请求头和Cookie...")
        // 设置Cookie
        let cookies = [
            "_uuid=768ccf7d4c29df0ba4ac9267aedf1a83",
            "selectMallId=11031",
            "_user_checkin_group=0",
            "_mid=11992",
            "_bussinessSrc=%7B%22BusinessSourceID%22%3A2%7D"
        ].joined(separator: "; ")
        request.setValue(cookies, forHTTPHeaderField: "Cookie")

        let bonusRequest = GetBonusRequest(
            MallID: mallID,
            ISRealBonus: true,
            Header: GetBonusRequest.RequestHeader(Token: token)
        )

        print("正在编码请求数据...")
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(bonusRequest)

        print("发送积分查询请求...")
        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let httpResponse = httpResponse as? HTTPURLResponse {
            print("收到服务器响应，状态码: \(httpResponse.statusCode)")

            if let responseString = String(data: data, encoding: .utf8) {
                print("响应数据: \(responseString)")
            }
        }

        print("正在解析响应数据...")
        let bonusResponse = try JSONDecoder().decode(BonusResponse.self, from: data)

        if bonusResponse.m == 1 && bonusResponse.d != nil {
            print("积分查询成功，积分数量: \(bonusResponse.d!.Bonus)")
            return bonusResponse.d!.Bonus
        }

        print("积分查询失败，响应代码: \(bonusResponse.m)")
        throw APIError.invalidResponse
    }

    func getVoucherCount(token: String) async throws -> Int {
        print("开始查询停车券数量，使用token: \(String(token.prefix(10)))...")

        var aboutToExpireCount: Int = 0
        var notAboutToExpireCount: Int = 0
        var aboutToExpireError: Error?
        var notAboutToExpireError: Error?

        do {
            aboutToExpireCount = try await getVoucherCountFromNewAPI(token: token)
        } catch {
            aboutToExpireError = error
        }

        do {
            notAboutToExpireCount = try await getVoucherCountFromOldAPI(token: token)
        } catch {
            notAboutToExpireError = error
        }

        if let aboutToExpireError, let notAboutToExpireError {
            print("查询停车券数量失败：\(aboutToExpireError.localizedDescription)，\(notAboutToExpireError.localizedDescription)")
            throw aboutToExpireError
        }

        let total = aboutToExpireCount + notAboutToExpireCount
        print("停车券数量汇总：即将过期 \(aboutToExpireCount) + 未过期 \(notAboutToExpireCount) = \(total)")
        return total
    }

    // 添加新的接口方法
    private func getVoucherCountFromNewAPI(token: String) async throws -> Int {
        guard let url = URL(string: "https://m-bms.cmsk1979.com/a/coupon/API/mycoupon/GetAboutToExpireCoupon") else {
            throw APIError.networkError("无效的URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://m-bms.cmsk1979.com/v/coupon/mycoupon/index?mid=11992", forHTTPHeaderField: "Referer")

        // 构建请求体
        let requestBody = [
            "MinID": 0,
            "PageSize": 999,
            "MallID": "11992",
            "Header": ["Token": token]
        ] as [String : Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(VoucherResponse.self, from: data)

        if response.m == 1 {
            let validVouchers = response.d?.filter { $0.Name.contains("停车券") } ?? []
            print("新接口 - 停车券数量查询成功，数量: \(validVouchers.count)")
            return validVouchers.count
        }

        throw APIError.invalidResponse
    }

    // 重命名原有方法为旧接口方法
    private func getVoucherCountFromOldAPI(token: String) async throws -> Int {
        guard let url = URL(string: "\(baseURL.replacingOccurrences(of: "/api", with: "/a/coupon/API/mycoupon/GetNotAboutToExpireCoupon"))") else {
            print("无效的URL")
            throw APIError.networkError("无效的URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://m-bms.cmsk1979.com/v/coupon/mycoupon/index?mid=11992", forHTTPHeaderField: "Referer")

        print("正在构建请求头和Cookie...")
        let cookies = [
            "_uuid=768ccf7d4c29df0ba4ac9267aedf1a83",
            "selectMallId=11031",
            "_user_checkin_group=0",
            "_mid=11992",
            "_bussinessSrc=%7B%22BusinessSourceID%22%3A16%2C%22BusinessSourceData%22%3A15625%7D"
        ].joined(separator: "; ")
        request.setValue(cookies, forHTTPHeaderField: "Cookie")

        let voucherRequest = GetVoucherRequest(
            MinID: 0,
            PageSize: 999,
            MallID: "11992",
            Header: GetVoucherRequest.RequestHeader(Token: token)
        )

        print("正在编码请求数据...")
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(voucherRequest)

        print("发送停车券数量查询请求...")
        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let httpResponse = httpResponse as? HTTPURLResponse {
            print("收到服务器响应，状态码: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("响应数据: \(responseString)")
            }
        }

        print("正在解析响应数据...")
        let voucherResponse = try JSONDecoder().decode(VoucherResponse.self, from: data)

        if voucherResponse.m == 1 {
            if voucherResponse.d == nil || voucherResponse.d?.isEmpty == true || voucherResponse.e == "暂无数据" {
                print("没有停车券数据，数量为0")
                return 0
            }

            let validVouchers = voucherResponse.d?.filter { $0.Name.contains("停车券") } ?? []
            print("停车券数量查询成功，数量: \(validVouchers.count)")
            return validVouchers.count
        }

        print("停车券数量查询失败，响应代码: \(voucherResponse.m)")
        throw APIError.invalidResponse
    }

    func exchangeVoucher(
        token: String,
        uid: String,
        count: Int,
        mid: String,
        gid: String,
        cardLevel: Int? = nil,
        cardTitle: String? = nil
    ) async throws -> String {
        print("开始兑换停车券，使用token: \(String(token.prefix(10)))...")
        let resolvedGID = try await resolveExchangeGiftID(
            mid: mid,
            gid: gid,
            cardLevel: cardLevel,
            cardTitle: cardTitle
        )
        let exchangeContext = try await resolveGiftExchangeContext(
            token: token,
            uid: uid,
            mid: mid,
            gid: resolvedGID,
            cardLevel: cardLevel,
            cardTitle: cardTitle
        )

        do {
            let orderNo = try await exchangeVoucherWithOldAPI(
                token: token,
                count: count,
                mid: mid,
                gid: resolvedGID,
                did: exchangeContext.discountID,
                cardLevel: cardLevel,
                cardTitle: cardTitle
            )
            return orderNo
        } catch {
            print("旧接口兑换失败，尝试新接口: \(error.localizedDescription)")
            return try await exchangeVoucherWithNewAPI(
                token: token,
                count: count,
                mid: mid,
                gid: resolvedGID,
                did: exchangeContext.discountID,
                cardLevel: cardLevel,
                cardTitle: cardTitle
            )
        }
    }

    // 添加新的兑换接口方法
    private func exchangeVoucherWithNewAPI(
        token: String,
        count: Int,
        mid: String,
        gid: String,
        did: String,
        cardLevel: Int?,
        cardTitle: String?
    ) async throws -> String {
        guard let url = URL(string: "https://m-bms.cmsk1979.com/a/coupon/API/mycoupon/ExchangeCoupon") else {
            throw APIError.networkError("无效的URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")

        // 构建请求体
        var requestBody: [String: Any] = [
            "mid": mid,
            "gid": gid,
            "c": count,
            "s": "11",
            "cbu": "https://m-bms.cmsk1979.com/a/gift/\(mid)/result?oid=",
            "did": did,
            "exp": NSNull(),
            "IsSplitOrder": true,
            "Header": ["Token": token]
        ]

        if let cardLevel {
            requestBody["CardLevel"] = cardLevel
        }

        if let cardTitle, !cardTitle.isEmpty {
            requestBody["CardTitle"] = cardTitle
        }

        let body = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = body

        logRequest(label: "Exchange(NewAPI)", request: request, body: body, tokenToMask: token)
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        logResponse(label: "Exchange(NewAPI)", response: httpResponse, data: data, tokenToMask: token)

        let exchangeResponse = try JSONDecoder().decode(ExchangeResponse.self, from: data)

        if exchangeResponse.m == 1, let orderNo = exchangeResponse.OrderNo {
            print("新接口兑换成功，订单号: \(orderNo)")
            return orderNo
        }

        let errorMessage = exchangeResponse.e ?? "兑换失败"
        print("新接口兑换失败: \(errorMessage)")
        throw APIError.loginFailed(errorMessage)
    }

    // 重命名原有方法为旧接口方法
    private func exchangeVoucherWithOldAPI(
        token: String,
        count: Int,
        mid: String,
        gid: String,
        did: String,
        cardLevel: Int?,
        cardTitle: String?
    ) async throws -> String {
        print("开始使用旧接口兑换停车券...")
        let url = URL(string: "\(baseURL)/gift/giftmanager/DoExchange")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(miniProgramUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(miniProgramReferer, forHTTPHeaderField: "Referer")

        let exchangeRequest = ExchangeRequest(
            mid: mid,
            gid: gid,
            c: count,
            s: "11",
            cbu: "https://m-bms.cmsk1979.com/a/gift/\(mid)/result?oid=",
            did: did,
            exp: nil,
            IsSplitOrder: true,
            CardLevel: cardLevel,
            CardTitle: cardTitle,
            Header: MiniProgramHeader(Token: token, systemInfo: .default)
        )

        print("正在编码请求数据...")
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(exchangeRequest)

        logRequest(label: "Exchange(OldAPI)", request: request, body: request.httpBody, tokenToMask: token)
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        logResponse(label: "Exchange(OldAPI)", response: httpResponse, data: data, tokenToMask: token)

        print("正在解析响应数据...")
        let exchangeResponse = try JSONDecoder().decode(ExchangeResponse.self, from: data)

        if exchangeResponse.m == 1, let orderNo = exchangeResponse.OrderNo {
            print("兑换成功，订单号: \(orderNo)")
            return orderNo
        }

        let errorMessage = exchangeResponse.e ?? "兑换失败"
        print("兑换失败: \(errorMessage)")
        throw APIError.loginFailed(errorMessage)
    }
}

final class MallCardAutoRepairService: @unchecked Sendable {
    static let shared = MallCardAutoRepairService()

    struct RepairResult {
        let latestToken: String
        let submittedCount: Int
        let failedCount: Int

        var summaryText: String {
            "成功 \(submittedCount) · 失败 \(failedCount)"
        }
    }

    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.69(0x1800452e) NetType/WIFI Language/zh_CN"
    private let origin = "https://m-bms.cmsk1979.com"
    private let shenzhenWechatOpenID = "oXCuFjuiSUD1fUH_HLHJCini5jvE"
    private let shenzhenMiniOpenID = "okZUd5BXnY0sJEZWGIypBnkNi0_g"
    private let shenzhenMiniUnionID = "undefined"
    private let shenzhenBusinessSourceID = "16"
    private let shenzhenBusinessSourceData = ""
    private let shenzhenBirthday = "1985-01-01"
    private let shenzhenRemark1 = "南山蛇口"
    private let shenzhenGender = "1"
    private let shenzhenHaiShangWorldMallID = 11027
    private let ganzhouMallID = 12073
    private let sanyaYazhouMallID = 12649
    private let ganzhouFixedIDNumber = "131121200007099415"
    private let ganzhouFixedAge = "41"
    private let allMallBatchTargets: [MallCardRepairTarget] = [
        .init(mallID: 10431, name: "南京招商花园城"),
        .init(mallID: 10724, name: "招商花园城（燕子矶店）"),
        .init(mallID: 11027, name: "深圳海上世界"),
        .init(mallID: 11031, name: "沈阳花园城"),
        .init(mallID: 11033, name: "毕节招商花园城"),
        .init(mallID: 11113, name: "宝山花园城"),
        .init(mallID: 11187, name: "森兰花园城"),
        .init(mallID: 11217, name: "苏州花园里商业广场"),
        .init(mallID: 11240, name: "成都成华招商花园城"),
        .init(mallID: 11405, name: "宁波1872花园坊"),
        .init(mallID: 11701, name: "杭州七堡花园城"),
        .init(mallID: 11992, name: "徐州招商花园城"),
        .init(mallID: 11994, name: "深圳会展湾商业"),
        .init(mallID: 11996, name: "琴湖溪里花园城"),
        .init(mallID: 12065, name: "成都大魔方招商花园城"),
        .init(mallID: 12072, name: "成都高新招商花园城"),
        .init(mallID: 12073, name: "赣州招商花园城"),
        .init(mallID: 12074, name: "九江招商花园城"),
        .init(mallID: 12075, name: "昆山招商花园城"),
        .init(mallID: 12080, name: "招商商管虚拟项目"),
        .init(mallID: 12140, name: "太子湾花园城"),
        .init(mallID: 12141, name: "上海东虹桥商业中心"),
        .init(mallID: 12147, name: "苏州金融小镇"),
        .init(mallID: 12225, name: "十堰花园城"),
        .init(mallID: 12226, name: "厦门海上世界"),
        .init(mallID: 12350, name: "湛江招商花园城"),
        .init(mallID: 12373, name: "曹路招商花园城"),
        .init(mallID: 12414, name: "成都天府招商花园城"),
        .init(mallID: 12415, name: "博鳌乐城招商花园里"),
        .init(mallID: 12447, name: "厦门海沧招商花园城"),
        .init(mallID: 12515, name: "宁波鄞州花园里"),
        .init(mallID: 12616, name: "珠海斗门招商花园城"),
        .init(mallID: 12649, name: "三亚崖州招商花园里"),
        .init(mallID: 12653, name: "长沙观沙岭招商花园城"),
        .init(mallID: 12654, name: "长沙梅溪湖花园城"),
        .init(mallID: 12655, name: "少荃体育中心花园里"),
        .init(mallID: 12792, name: "上海海上世界"),
        .init(mallID: 12795, name: "成都金牛招商花园城"),
        .init(mallID: 12797, name: "南京玄武招商花园城"),
        .init(mallID: 12908, name: "招商绿洲智谷花园里"),
        .init(mallID: 12909, name: "璀璨花园里"),
        .init(mallID: 12994, name: "杭州城北招商花园城")
    ]
    private let preferredScoreMallIDs: [Int] = [12649, 11701, 11113, 12075]

    func repairAllMallCards(token: String, phone: String) async throws -> RepairResult {
        let cleanedPhone = phone.filter(\.isNumber)
        guard cleanedPhone.count == 11 else {
            throw APIService.APIError.networkError("账号手机号无效，无法自动补开卡")
        }

        let userName = randomChineseName()
        let email = randomEmail()
        let address = randomAddress()
        var submitted: [String] = []
        var failed: [String] = []
        var currentToken = token

        log("开始自动补开全商场会员卡，手机号：\(cleanedPhone)")

        for target in orderedBatchMallTargets {
            do {
                let setting = try? await loadMallCardSetting(mallID: target.mallID, token: currentToken)
                let mcSetting = batchMCSetting(
                    for: target,
                    setting: setting,
                    userName: userName,
                    email: email,
                    address: address
                )

                currentToken = try await submitMallProfileAndOpenCardIfNeeded(
                    mallID: target.mallID,
                    phone: cleanedPhone,
                    token: currentToken,
                    mcSetting: mcSetting,
                    setting: setting
                )
                submitted.append(target.name)
            } catch {
                failed.append("\(target.name)：\(error.localizedDescription)")
            }
        }

        for target in preferredScoreMallTargets {
            do {
                let setting = try? await loadMallCardSetting(mallID: target.mallID, token: currentToken)
                let mcSetting = preferredMallMCSetting(
                    for: target,
                    setting: setting,
                    userName: userName,
                    email: email,
                    address: address
                )
                currentToken = try await submitMallProfileAndOpenCardIfNeeded(
                    mallID: target.mallID,
                    phone: cleanedPhone,
                    token: currentToken,
                    mcSetting: mcSetting,
                    setting: setting
                )
            } catch {
                failed.append("\(target.name) 补提：\(error.localizedDescription)")
            }
        }

        guard !submitted.isEmpty else {
            if let firstFailure = failed.first {
                throw APIService.APIError.networkError("自动补开卡未成功：\(firstFailure)")
            }
            throw APIService.APIError.networkError("自动补开卡未成功：当前没有可提交的商场")
        }

        log("自动补开全商场会员卡完成，手机号：\(cleanedPhone)，成功 \(submitted.count) 个，失败 \(failed.count) 个")
        return RepairResult(
            latestToken: currentToken,
            submittedCount: submitted.count,
            failedCount: failed.count
        )
    }

    private var orderedBatchMallTargets: [MallCardRepairTarget] {
        allMallBatchTargets.sorted { lhs, rhs in
            let leftIndex = preferredScoreMallIDs.firstIndex(of: lhs.mallID) ?? Int.max
            let rightIndex = preferredScoreMallIDs.firstIndex(of: rhs.mallID) ?? Int.max
            if leftIndex == rightIndex {
                return lhs.mallID < rhs.mallID
            }
            return leftIndex < rightIndex
        }
    }

    private var preferredScoreMallTargets: [MallCardRepairTarget] {
        preferredScoreMallIDs.compactMap { preferredMallID in
            allMallBatchTargets.first { $0.mallID == preferredMallID }
        }
    }

    private func loadMallCardSetting(mallID: Int, token: String) async throws -> MallCardRepairSetting {
        let body = MallCardRepairSettingBody(
            MallID: mallID,
            Header: .init(Token: token, systemInfo: .default)
        )
        let response: MallCardRepairCommonResponse<MallCardRepairSetting> = try await cmskRequest(
            path: "/api/user/MallCardSetting/GetForOpenCard",
            body: body
        )
        guard response.m == 1, let setting = response.d else {
            throw APIService.APIError.networkError(response.e ?? "商场配置获取失败")
        }
        return setting
    }

    private func submitMallProfileAndOpenCardIfNeeded(
        mallID: Int,
        phone: String,
        token: String,
        mcSetting: String,
        setting: MallCardRepairSetting?
    ) async throws -> String {
        let body = MallCardRepairPostUserBody(
            MallID: mallID,
            MallCardID: 0,
            mcSetting: mcSetting,
            OauthID: "",
            DataSource: 3,
            Header: .init(Token: token, systemInfo: .default)
        )
        let response: MallCardRepairCommonResponse<Int> = try await cmskRequest(
            path: "/api/user/user/PostUser",
            body: body
        )
        guard response.m == 1 else {
            throw APIService.APIError.networkError(response.e ?? "资料提交失败")
        }

        return try await openMallCardIfNeeded(
            mallID: mallID,
            phone: phone,
            token: token,
            mcSetting: mcSetting,
            setting: setting
        )
    }

    private func openMallCardIfNeeded(
        mallID: Int,
        phone: String,
        token: String,
        mcSetting: String,
        setting: MallCardRepairSetting?
    ) async throws -> String {
        guard let setting else {
            return token
        }

        guard setting.IsOpenCard || setting.IsBindCard else {
            return token
        }

        let checkBody = MallCardRepairCheckBody(
            MallID: mallID,
            Mobile: phone,
            mcSetting: mcSetting,
            Header: .init(Token: token, systemInfo: .default)
        )
        let checkResponse: MallCardRepairCommonResponse<Int> = try await cmskRequest(
            path: "/api/user/user/CheckMallCard",
            body: checkBody
        )
        guard checkResponse.m == 1 else {
            throw APIService.APIError.networkError(checkResponse.e ?? "开卡资料校验失败")
        }

        let openCardBody = MallCardRepairOpenBody(
            MallID: mallID,
            Mobile: phone,
            mcSetting: "{}",
            SNSType: 3,
            RefID: "",
            DataSource: 11,
            InvitedUID: nil,
            UnionID: shenzhenMiniUnionID,
            BusinessSourceID: shenzhenBusinessSourceID,
            BusinessSourceData: shenzhenBusinessSourceData,
            OauthID: shenzhenWechatOpenID,
            MiniOpenID: shenzhenMiniOpenID,
            Header: .init(Token: token, systemInfo: .default)
        )
        let openCardResponse: MallCardRepairCommonResponse<MallCardRepairOpenResponseData> = try await cmskRequest(
            path: "/api/user/user/OpenOrBindCard",
            body: openCardBody
        )

        if openCardResponse.m == 307 {
            return token
        }

        guard openCardResponse.m == 1, let openData = openCardResponse.d else {
            throw APIService.APIError.networkError(openCardResponse.e ?? "开卡失败")
        }

        return "\(openData.Token),\(openData.ProjectType)"
    }

    private func batchMCSetting(
        for target: MallCardRepairTarget,
        setting: MallCardRepairSetting?,
        userName: String,
        email: String,
        address: String
    ) -> String {
        switch target.mallID {
        case shenzhenHaiShangWorldMallID:
            return shenzhenHaiShangWorldMCSetting(userName: userName, email: email, address: address)
        case ganzhouMallID:
            return ganzhouMcSetting(userName: userName)
        case sanyaYazhouMallID:
            return sanyaYazhouMcSetting()
        default:
            return genericMallMCSetting(
                fieldNames: mergedMallFieldNames(from: setting),
                userName: userName,
                email: email,
                address: address
            )
        }
    }

    private func preferredMallMCSetting(
        for target: MallCardRepairTarget,
        setting: MallCardRepairSetting?,
        userName: String,
        email: String,
        address: String
    ) -> String {
        genericMallMCSetting(
            fieldNames: mergedMallFieldNames(from: setting, includeDefaultCompletionFields: true),
            userName: userName,
            email: email,
            address: address,
            overrides: preferredMallPayloadOverrides(for: target)
        )
    }

    private func mergedMallFieldNames(
        from setting: MallCardRepairSetting?,
        includeDefaultCompletionFields: Bool = false
    ) -> [String] {
        var merged = Set<String>()

        if let setting {
            merged.formUnion((setting.RequiredFieldsList ?? []).map(\.Name))
            merged.formUnion((setting.ProfileFieldsList ?? []).map(\.Name))
            merged.formUnion((setting.MallCardOptionsList ?? []).map(\.Name))
        }

        if includeDefaultCompletionFields || merged.isEmpty {
            merged.formUnion(defaultBatchMallFieldNames)
        }

        if merged.contains("ShoppingInterest") || merged.contains("ShoppingInterestList") {
            merged.formUnion(["ShoppingInterest", "ShoppingInterestList"])
        }
        if merged.contains("Hobby") || merged.contains("HobbyList") {
            merged.formUnion(["Hobby", "HobbyList"])
        }
        if merged.contains("ActiveInterest") || merged.contains("ActiveInterestList") {
            merged.formUnion(["ActiveInterest", "ActiveInterestList"])
        }
        if merged.contains("HasChildren") {
            merged.insert("ChildrenCount")
        }

        return orderedMallFieldNames(from: merged)
    }

    private func orderedMallFieldNames(from fieldNames: Set<String>) -> [String] {
        let defaultFieldSet = Set(defaultBatchMallFieldNames)
        let orderedDefaults = defaultBatchMallFieldNames.filter(fieldNames.contains)
        let extras = fieldNames.subtracting(defaultFieldSet).sorted()
        return orderedDefaults + extras
    }

    private func preferredMallPayloadOverrides(for target: MallCardRepairTarget) -> [String: String] {
        switch target.mallID {
        case 12649:
            return ["Education": "1"]
        default:
            return [:]
        }
    }

    private func defaultMallPayloadValues(
        userName: String,
        email: String,
        address: String,
        overrides: [String: String] = [:]
    ) -> [String: String] {
        let defaults: [String: String] = [
            "UserName": userName,
            "Gender": shenzhenGender,
            "Birthday": shenzhenBirthday,
            "Age": ganzhouFixedAge,
            "HasChildren": "1",
            "ChildrenCount": "1",
            "Conveyance": "0",
            "Address": address,
            "Email": email,
            "ShoppingInterest": "2,6",
            "ShoppingInterestList": "2,6",
            "Hobby": "2,6",
            "HobbyList": "2,6",
            "ActiveInterest": "1,2",
            "ActiveInterestList": "1,2",
            "IDNum": ganzhouFixedIDNumber,
            "ProvincialAreas": #"{"ProvinceID":110000,"Province":"北京市","CityID":110100,"City":"北京市","DistrictsID":110101,"Districts":"东城区"}"#,
            "Business": "互联网",
            "Marital": "0",
            "Income": "3",
            "Education": "2",
            "Remark1": shenzhenRemark1,
            "Remark2": "A座",
            "Remark5": "否",
            "CarNO": "粤B12345",
            "Reference": "老会员"
        ]
        return defaults.merging(overrides) { _, newValue in newValue }
    }

    private func genericMallMCSetting(
        fieldNames: [String],
        userName: String,
        email: String,
        address: String,
        overrides: [String: String] = [:]
    ) -> String {
        let defaults = defaultMallPayloadValues(
            userName: userName,
            email: email,
            address: address,
            overrides: overrides
        )

        let payload = fieldNames.reduce(into: [String: String]()) { partialResult, fieldName in
            if let value = defaults[fieldName] {
                partialResult[fieldName] = value
            }
        }

        guard !payload.isEmpty else {
            return "{}"
        }
        return encodeMallPayload(payload)
    }

    private var defaultBatchMallFieldNames: [String] {
        [
            "UserName",
            "Gender",
            "Birthday",
            "Age",
            "HasChildren",
            "ChildrenCount",
            "Conveyance",
            "Address",
            "Email",
            "ShoppingInterest",
            "ShoppingInterestList",
            "Hobby",
            "HobbyList",
            "ActiveInterest",
            "ActiveInterestList",
            "IDNum",
            "ProvincialAreas",
            "Business",
            "Marital",
            "Income",
            "Education",
            "Remark1",
            "Remark2",
            "Remark5",
            "CarNO",
            "Reference"
        ]
    }

    private func encodeMallPayload(_ payload: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func shenzhenHaiShangWorldMCSetting(userName: String, email: String, address: String) -> String {
        encodeMallPayload([
            "Birthday": shenzhenBirthday,
            "Gender": shenzhenGender,
            "UserName": userName,
            "Email": email,
            "Address": address,
            "HasChildren": "1",
            "ShoppingInterestList": "2,6",
            "HobbyList": "2,6",
            "Conveyance": "0"
        ])
    }

    private func ganzhouMcSetting(userName: String) -> String {
        encodeMallPayload([
            "UserName": userName,
            "Gender": shenzhenGender,
            "Birthday": shenzhenBirthday,
            "Age": ganzhouFixedAge,
            "HasChildren": "1",
            "IDNum": ganzhouFixedIDNumber,
            "Conveyance": "0",
            "ActiveInterestList": "1,2",
            "ShoppingInterestList": "2,6"
        ])
    }

    private func sanyaYazhouMcSetting() -> String {
        encodeMallPayload([
            "Gender": shenzhenGender,
            "Birthday": shenzhenBirthday,
            "ProvincialAreas": "{\"ProvinceID\":110000,\"Province\":\"北京市\",\"CityID\":110100,\"City\":\"北京市\",\"DistrictsID\":110101,\"Districts\":\"东城区\"}",
            "Education": "1",
            "Marital": "0",
            "HasChildren": "1",
            "Conveyance": "0"
        ])
    }

    private func randomChineseName() -> String {
        let surnames = Array("赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦尤许何吕施张孔曹严华金魏陶姜")
        let given = Array("安柏晨楚达恩凡歌浩嘉景凯乐铭宁琪然书婷雯欣妍宇泽知子")
        let surname = String(surnames.randomElement() ?? "张")
        let first = String(given.randomElement() ?? "子")
        let second = String(given.randomElement() ?? "涵")
        return surname + first + second
    }

    private func randomEmail() -> String {
        let local = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(10)
        return "\(local)@test.com"
    }

    private func randomAddress() -> String {
        let districts = ["南山区", "福田区", "罗湖区", "宝安区", "龙岗区"]
        let roads = ["招商街道", "海上世界广场", "望海路", "工业一路", "太子路"]
        let district = districts.randomElement() ?? "南山区"
        let road = roads.randomElement() ?? "海上世界广场"
        let number = Int.random(in: 1...999)
        return "深圳市\(district)\(road)\(number)号"
    }

    private func cmskRequest<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(origin)\(path)") else {
            throw APIService.APIError.networkError("接口地址错误")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(origin, forHTTPHeaderField: "Origin")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw APIService.APIError.networkError("HTTP \(httpResponse.statusCode)：\(raw)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "无法解析响应"
            throw APIService.APIError.networkError(raw)
        }
    }

    private func log(_ message: String) {
        Task { @MainActor in
            LogStore.shared.add(category: "CHECKIN", message)
        }
    }
}

private struct MallCardRepairTarget {
    let mallID: Int
    let name: String
}

private struct MallCardRepairSystemInfo: Codable {
    let model: String
    let SDKVersion: String
    let system: String
    let version: String
    let miniVersion: String

    static let `default` = MallCardRepairSystemInfo(
        model: "iPhone 15 pro max<iPhone16,2>",
        SDKVersion: "3.14.3",
        system: "iOS 18.4",
        version: "8.0.69",
        miniVersion: "1.0.76"
    )
}

private struct MallCardRepairHeader: Codable {
    let Token: String
    let systemInfo: MallCardRepairSystemInfo
}

private struct MallCardRepairCommonResponse<T: Decodable>: Decodable {
    let m: Int
    let d: T?
    let e: String?
}

private struct MallCardRepairSettingBody: Codable {
    let MallID: Int
    let Header: MallCardRepairHeader
}

private struct MallCardRepairField: Decodable {
    let Name: String
}

private struct MallCardRepairSetting: Decodable {
    let IsOpenCard: Bool
    let IsBindCard: Bool
    let RequiredFieldsList: [MallCardRepairField]?
    let ProfileFieldsList: [MallCardRepairField]?
    let MallCardOptionsList: [MallCardRepairField]?
}

private struct MallCardRepairPostUserBody: Codable {
    let MallID: Int
    let MallCardID: Int
    let mcSetting: String
    let OauthID: String
    let DataSource: Int
    let Header: MallCardRepairHeader
}

private struct MallCardRepairCheckBody: Codable {
    let MallID: Int
    let Mobile: String
    let mcSetting: String
    let Header: MallCardRepairHeader
}

private struct MallCardRepairOpenBody: Codable {
    let MallID: Int
    let Mobile: String
    let mcSetting: String
    let SNSType: Int
    let RefID: String
    let DataSource: Int
    let InvitedUID: Int?
    let UnionID: String
    let BusinessSourceID: String
    let BusinessSourceData: String
    let OauthID: String
    let MiniOpenID: String
    let Header: MallCardRepairHeader
}

private struct MallCardRepairOpenResponseData: Decodable {
    let Token: String
    let ProjectType: Int
}
