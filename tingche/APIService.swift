// Purpose: Network API client for login, bonus, voucher count, gift discovery, and voucher exchange.
// Author: Achord <achordchan@gmail.com>
import Foundation
import SwiftUI

// API服务
class APIService {
    static let shared = APIService()
    private let baseURL = "https://m-bms.cmsk1979.com/api"
    @Published var currentToken: String?
    private let debugNetwork = true

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
            "Header": [
                "Token": token,
                "systemInfo": [
                    "miniVersion": "1.0.70",
                    "system": "iOS 18.4",
                    "model": "iPhone 15 pro max<iPhone16,2>",
                    "SDKVersion": "3.10.3",
                    "version": "8.0.62"
                ]
            ]
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

    func discoverParkingVoucherGift(token: String, mid: String) async throws -> GiftInfoListItem {
        let gifts = try await getGiftInfoList(token: token, mid: mid)
        let candidates = gifts.filter { $0.n.contains("停车券") }
        guard !candidates.isEmpty else {
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
        let Header: RequestHeader

        struct RequestHeader: Codable {
            let Token: String
        }
    }

    struct ExchangeResponse: Codable {
        let oid: Int?
        let OrderNo: String?
        let m: Int
        let e: String?
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
        print("开始查询积分，使用token: \(String(token.prefix(10)))...")
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
            MallID: "11992",
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

    func exchangeVoucher(token: String, count: Int, mid: String, gid: String) async throws -> String {
        print("开始兑换停车券，使用token: \(String(token.prefix(10)))...")

        // 尝试新接口
        do {
            let orderNo = try await exchangeVoucherWithNewAPI(token: token, count: count, mid: mid, gid: gid)
            return orderNo
        } catch {
            print("新接口兑换失败，尝试旧接口: \(error.localizedDescription)")
            // 如果新接口失败，尝试旧接口
            return try await exchangeVoucherWithOldAPI(token: token, count: count, mid: mid, gid: gid)
        }
    }

    // 添加新的兑换接口方法
    private func exchangeVoucherWithNewAPI(token: String, count: Int, mid: String, gid: String) async throws -> String {
        guard let url = URL(string: "https://m-bms.cmsk1979.com/a/coupon/API/mycoupon/ExchangeCoupon") else {
            throw APIError.networkError("无效的URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://m-bms.cmsk1979.com/v/marketing/gift/confirm?gid=\(gid)&mid=\(mid)", forHTTPHeaderField: "Referer")

        // 构建请求体
        let requestBody = [
            "mid": mid,
            "gid": gid,
            "c": count,
            "s": "11",
            "cbu": "https://m-bms.cmsk1979.com/a/gift/\(mid)/result?oid=",
            "did": "",
            "exp": nil,
            "Header": ["Token": token]
        ] as [String : Any]

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
    private func exchangeVoucherWithOldAPI(token: String, count: Int, mid: String, gid: String) async throws -> String {
        print("开始使用旧接口兑换停车券...")
        let url = URL(string: "\(baseURL)/gift/giftmanager/DoExchange")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://m-bms.cmsk1979.com/v/marketing/gift/confirm?gid=\(gid)&mid=\(mid)", forHTTPHeaderField: "Referer")

        print("正在构建请求头和Cookie...")
        let cookies = [
            "_uuid=768ccf7d4c29df0ba4ac9267aedf1a83",
            "selectMallId=11031",
            "_user_checkin_group=0",
            "_mid=\(mid)",
            "_bussinessSrc=%7B%22BusinessSourceID%22%3A2%7D"
        ].joined(separator: "; ")
        request.setValue(cookies, forHTTPHeaderField: "Cookie")

        let exchangeRequest = ExchangeRequest(
            mid: mid,
            gid: gid,
            c: count,
            s: "11",
            cbu: "https://m-bms.cmsk1979.com/a/gift/\(mid)/result?oid=",
            did: "",
            exp: nil,
            Header: ExchangeRequest.RequestHeader(Token: token)
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
