//
//  ContentView.swift
//  tingche1
//
//  Created by A chord on 2025/2/19.
//

import SwiftUI
import WebKit

// API服务
class APIService {
    static let shared = APIService()
    private let baseURL = "https://m-bms.cmsk1979.com/api"
    @Published var currentToken: String?
    
    enum APIError: Error {
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
        // 其他字段可以根据需要添加
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
        // 其他字段可以根据需要添加
    }
    
    struct VoucherResponse: Codable {
        let m: Int
        let d: [VoucherItem]?
        let e: String?
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
            } else {
                let errorMessage = response.e ?? "未知错误"
                throw APIError.loginFailed(errorMessage)
            }
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
            
            // 打印响应数据，帮助调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("响应数据: \(responseString)")
            }
        }
        
        print("正在解析响应数据...")
        let bonusResponse = try JSONDecoder().decode(BonusResponse.self, from: data)
        
        if bonusResponse.m == 1 && bonusResponse.d != nil {
            print("积分查询成功，积分数量: \(bonusResponse.d!.Bonus)")
            return bonusResponse.d!.Bonus
        } else {
            print("积分查询失败，响应代码: \(bonusResponse.m)")
            throw APIError.invalidResponse
        }
    }
    
    func getVoucherCount(token: String) async throws -> Int {
        print("开始查询停车券数量，使用token: \(String(token.prefix(10)))...")
        
        // 尝试新接口
        do {
            let count = try await getVoucherCountFromNewAPI(token: token)
            
            // 如果新接口返回数量大于0，则直接返回结果
            if count > 0 {
                print("新接口返回停车券数量: \(count)，直接使用该结果")
                return count
            }
            
            // 如果新接口返回数量为0，则尝试旧接口确认
            print("新接口返回停车券数量为0，尝试旧接口确认...")
            let oldCount = try await getVoucherCountFromOldAPI(token: token)
            
            // 比较两个接口的结果
            if oldCount > 0 {
                print("旧接口返回停车券数量为: \(oldCount)，使用旧接口结果")
                return oldCount
            } else {
                print("两个接口都返回0张停车券，确认用户没有停车券")
                return 0
            }
        } catch {
            print("新接口查询失败，尝试旧接口: \(error.localizedDescription)")
            // 如果新接口失败，尝试旧接口
            return try await getVoucherCountFromOldAPI(token: token)
        }
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
        } else {
            throw APIError.invalidResponse
        }
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
            PageSize: 10,
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
        } else {
            print("停车券数量查询失败，响应代码: \(voucherResponse.m)")
            throw APIError.invalidResponse
        }
    }
    
    func exchangeVoucher(token: String, count: Int) async throws -> String {
        print("开始兑换停车券，使用token: \(String(token.prefix(10)))...")
        
        // 尝试新接口
        do {
            let orderNo = try await exchangeVoucherWithNewAPI(token: token, count: count)
            return orderNo
        } catch {
            print("新接口兑换失败，尝试旧接口: \(error.localizedDescription)")
            // 如果新接口失败，尝试旧接口
            return try await exchangeVoucherWithOldAPI(token: token, count: count)
        }
    }
    
    // 添加新的兑换接口方法
    private func exchangeVoucherWithNewAPI(token: String, count: Int) async throws -> String {
        guard let url = URL(string: "https://m-bms.cmsk1979.com/a/coupon/API/mycoupon/ExchangeCoupon") else {
            throw APIError.networkError("无效的URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://m-bms.cmsk1979.com/v/marketing/gift/confirm?gid=420117&mid=11992", forHTTPHeaderField: "Referer")
        
        // 构建请求体
        let requestBody = [
            "mid": "11992",
            "gid": "420117",
            "c": count,
            "s": "11",
            "cbu": "https://m-bms.cmsk1979.com/a/gift/11992/result?oid=",
            "did": "",
            "exp": nil,
            "Header": ["Token": token]
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("发送新接口兑换请求...")
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse {
            print("收到服务器响应，状态码: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("响应数据: \(responseString)")
            }
        }
        
        let exchangeResponse = try JSONDecoder().decode(ExchangeResponse.self, from: data)
        
        if exchangeResponse.m == 1 && exchangeResponse.OrderNo != nil {
            print("新接口兑换成功，订单号: \(exchangeResponse.OrderNo!)")
            return exchangeResponse.OrderNo!
        } else {
            let errorMessage = exchangeResponse.e ?? "兑换失败"
            print("新接口兑换失败: \(errorMessage)")
            throw APIError.loginFailed(errorMessage)
        }
    }
    
    // 重命名原有方法为旧接口方法
    private func exchangeVoucherWithOldAPI(token: String, count: Int) async throws -> String {
        print("开始使用旧接口兑换停车券...")
        let url = URL(string: "\(baseURL)/gift/giftmanager/DoExchange")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://m-bms.cmsk1979.com/v/marketing/gift/confirm?gid=420117&mid=11992", forHTTPHeaderField: "Referer")
        
        print("正在构建请求头和Cookie...")
        let cookies = [
            "_uuid=768ccf7d4c29df0ba4ac9267aedf1a83",
            "selectMallId=11031",
            "_user_checkin_group=0",
            "_mid=11992",
            "_bussinessSrc=%7B%22BusinessSourceID%22%3A2%7D"
        ].joined(separator: "; ")
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        
        let exchangeRequest = ExchangeRequest(
            mid: "11992",
            gid: "420117",
            c: count,
            s: "11",
            cbu: "https://m-bms.cmsk1979.com/a/gift/11992/result?oid=",
            did: "",
            exp: nil,
            Header: ExchangeRequest.RequestHeader(Token: token)
        )
        
        print("正在编码请求数据...")
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(exchangeRequest)
        
        print("发送兑换请求...")
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse {
            print("收到服务器响应，状态码: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("响应数据: \(responseString)")
            }
        }
        
        print("正在解析响应数据...")
        let exchangeResponse = try JSONDecoder().decode(ExchangeResponse.self, from: data)
        
        if exchangeResponse.m == 1 && exchangeResponse.OrderNo != nil {
            print("兑换成功，订单号: \(exchangeResponse.OrderNo!)")
            return exchangeResponse.OrderNo!
        } else {
            let errorMessage = exchangeResponse.e ?? "兑换失败"
            print("兑换失败: \(errorMessage)")
            throw APIError.loginFailed(errorMessage)
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.65),
                                    Color.accentColor.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 108, height: 108)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.55), lineWidth: 2)
                        )

                    AsyncImage(url: URL(string: "https://avatars.githubusercontent.com/u/179492542?v=4")) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "person.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 3)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 10)
                }

                VStack(spacing: 6) {
                    Text("Achord")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("花园城停车助手")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 22)
                    Text("作者：Achord")
                        .foregroundColor(.primary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 22)
                    Text("Tel：13160235855")
                        .foregroundColor(.primary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 22)
                    Text("Email：achordchan@gmail.com")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Link(destination: URL(string: "https://github.com/achordchan/garden_city")!) {
                    Label("项目地址", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://github.com/achordchan/garden_city")!) {
                    Label("隐私条款", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://github.com/achordchan/garden_city")!) {
                    Label("开源协议", systemImage: "doc.text.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://ifdian.net/a/achord")!) {
                    Label("赞助我", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.regular)

            Text("故事起源在22年底，我来到这家外贸公司工作\n本工具目的是为了统一管理花园城停车号码的管理，稍微加了一点更改响应和基础的兑换停车功能，除此之外未进行任何逆向破解，仅供学习，请24小时内删除。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.top, 2)
        }
        .padding(22)
        .frame(minWidth: 520, idealWidth: 640, maxWidth: 760, minHeight: 420, idealHeight: 460, maxHeight: 520)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.10),
                    Color.accentColor.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// 账号信息模型
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

// 账号管理类
class AccountManager: ObservableObject {
    @Published var accounts: [AccountInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .success
    @Published var isExecutingAll = false
    @Published var currentProcessingAccountId: UUID?
    private let accountsKey = "savedAccounts"
    private var resetTimer: Timer?
    
    enum ToastType {
        case success
        case error
        case info
        
        var backgroundColor: Color {
            switch self {
            case .success: return Color.green.opacity(0.9)
            case .error: return Color.red.opacity(0.9)
            case .info: return Color.blue.opacity(0.9)
            }
        }
        
        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    func showToast(_ message: String, type: ToastType) {
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastType = type
            self.showToast = true
            
            // 3秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showToast = false
            }
        }
    }
    
    init() {
        loadAccounts()
        checkAndResetStatus()
        setupResetTimer()
        setupNotificationObservers()
    }
    
    deinit {
        resetTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // 设置定时器在每天0点重置状态
    private func setupResetTimer() {
        // 获取下一个0点的时间
        let now = Date()
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        // 计算到下一个0点的时间间隔
        let timeInterval = nextMidnight.timeIntervalSince(now)
        
        // 设置定时器
        resetTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.resetAllProcessedStatus()
            // 重新设置下一天的定时器
            self?.setupResetTimer()
        }
    }
    
    // 添加检查和重置状态的方法
    private func checkAndResetStatus() {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取上次重置的日期（如果没有，默认为很早以前的日期）
        let lastResetDate = UserDefaults.standard.object(forKey: "lastResetDate") as? Date ?? Date.distantPast
        
        // 检查是否是不同的日期
        if !calendar.isDate(lastResetDate, inSameDayAs: now) {
            // 如果不是同一天，重置所有账号的状态
            for index in accounts.indices {
                accounts[index].isProcessedToday = false
            }
            saveAccounts()
            
            // 更新最后重置日期
            UserDefaults.standard.set(now, forKey: "lastResetDate")
            print("软件启动时检测到新的一天，已重置所有账号状态")
        }
    }
    
    // 修改原有的重置方法，同时更新最后重置日期
    func resetAllProcessedStatus() {
        DispatchQueue.main.async {
            for index in self.accounts.indices {
                self.accounts[index].isProcessedToday = false
            }
            self.saveAccounts()
            
            // 更新最后重置日期
            UserDefaults.standard.set(Date(), forKey: "lastResetDate")
            self.showToast("已重置所有账号的处理状态", type: .info)
        }
    }
    
    // 加载账号
    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountsKey) {
            do {
                accounts = try JSONDecoder().decode([AccountInfo].self, from: data)
                print("成功加载\(accounts.count)个账号")
            } catch {
                print("加载账号失败: \(error.localizedDescription)")
            }
        } else {
            print("没有找到保存的账号数据")
        }
    }
    
    // 保存账号
    func saveAccounts() {
        do {
            let data = try JSONEncoder().encode(accounts)
            UserDefaults.standard.set(data, forKey: accountsKey)
            print("成功保存\(accounts.count)个账号")
        } catch {
            print("保存账号失败: \(error.localizedDescription)")
        }
    }
    
    // 添加检查手机号是否存在的方法
    func isPhoneNumberExists(_ phoneNumber: String) -> Bool {
        return accounts.contains { $0.username == phoneNumber }
    }
    
    // 修改添加账号的方法
    func addAccountWithValidation(username: String, password: String) async -> Bool {
        // 先检查手机号是否已存在
        if isPhoneNumberExists(username) {
            await MainActor.run {
                self.errorMessage = "该手机号已存在，请勿重复添加"
                self.showToast("该手机号已存在，请勿重复添加", type: .error)
            }
            return false
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        
        do {
            let (isValid, token, uid) = try await APIService.shared.login(username: username, password: password)
            
            if isValid, let token {
                await MainActor.run {
                    self.successMessage = "登录成功！Token: \(token), UID: \(uid ?? "")"
                    self.addAccount(username: username, password: password, token: token, uid: uid)
                    self.isLoading = false
                }
                return true
            } else {
                await MainActor.run {
                    self.errorMessage = self.errorMessage ?? "登录失败，请检查账号密码"
                    self.isLoading = false
                }
                return false
            }
        } catch let error as APIService.APIError {
            await MainActor.run {
                self.errorMessage = error.message
                self.isLoading = false
            }
            return false
        } catch {
            await MainActor.run {
                self.errorMessage = "网络错误：\(error.localizedDescription)"
                self.isLoading = false
            }
            return false
        }
    }
    
    // 添加账号
    func addAccount(username: String, password: String, token: String? = nil, uid: String? = nil) {
        let account = AccountInfo(username: username, password: password, token: token, uid: uid)
        accounts.append(account)
        saveAccounts()
    }
    
    // 删除账号
    func deleteAccount(account: AccountInfo) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            let username = account.username
            
            // 通知 DataManager 记录删除操作
            NotificationCenter.default.post(
                name: .accountDeleted,
                object: account,
                userInfo: ["reason": "用户手动删除"]
            )
            
            accounts.remove(at: index)
            saveAccounts()
            showToast("已删除账号：\(username)", type: .info)
        }
    }
    
    // 更新账号状态
    func updateAccount(_ account: AccountInfo) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
        }
    }
    
    func refreshBonus(for account: AccountInfo) async {
        print("开始为账号 \(account.username) 刷新积分...")
        
        do {
            showToast("正在登录账号...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)
            
            if !isValid || newToken == nil {
                showToast("登录失败：\(uid ?? "未知错误")", type: .error)
                return
            }
            
            showToast("登录成功，正在查询积分...", type: .info)
            
            let bonus = try await APIService.shared.getBonus(token: newToken!)
            
            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.bonus = bonus
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accounts[index] = updatedAccount
                    saveAccounts()
                    showToast("积分刷新成功：\(bonus)分", type: .success)
                }
            }
        } catch {
            showToast("刷新积分失败：\(error.localizedDescription)", type: .error)
        }
    }
    
    func refreshVoucherCount(for account: AccountInfo) async {
        print("开始为账号 \(account.username) 刷新停车券数量...")
        
        do {
            showToast("正在登录账号...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)
            
            if !isValid || newToken == nil {
                showToast("登录失败：\(uid ?? "未知错误")", type: .error)
                return
            }
            
            showToast("登录成功，正在查询停车券...", type: .info)
            
            let voucherCount = try await APIService.shared.getVoucherCount(token: newToken!)
            
            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.voucherCount = voucherCount
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accounts[index] = updatedAccount
                    saveAccounts()
                    showToast("停车券刷新成功：\(voucherCount)张", type: .success)
                }
            }
        } catch {
            showToast("刷新停车券失败：\(error.localizedDescription)", type: .error)
        }
    }
    
    func exchangeVoucher(for account: AccountInfo, exchangeCount: Int) async {
        print("开始为账号 \(account.username) 兑换停车券...")
        
        do {
            showToast("正在登录账号...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)
            
            if !isValid || newToken == nil {
                showToast("登录失败：\(uid ?? "未知错误")", type: .error)
                return
            }
            
            showToast("登录成功，正在兑换停车券...", type: .info)
            
            let orderNo = try await APIService.shared.exchangeVoucher(token: newToken!, count: exchangeCount)
            
            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.isProcessedToday = true
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accounts[index] = updatedAccount
                    saveAccounts()
                    showToast("兑换成功！订单号：\(orderNo)", type: .success)
                }
            }
        } catch {
            showToast("兑换失败：\(error.localizedDescription)", type: .error)
        }
        
        // 无论兑换成功与否，都刷新停车券数量和积分
        showToast("正在刷新停车券数量...", type: .info)
        await refreshVoucherCount(for: account)
        
        showToast("正在刷新积分...", type: .info)
        await refreshBonus(for: account)
    }
    
    func executeAllAccounts(exchangeCount: Int) async {
        isExecutingAll = true
        showToast("开始批量兑换停车券...", type: .info)
        
        // 过滤出未处理的账号
        let unprocessedAccounts = accounts.filter { !$0.isProcessedToday }
        
        if unprocessedAccounts.isEmpty {
            showToast("没有需要处理的账号", type: .info)
            isExecutingAll = false
            currentProcessingAccountId = nil
            return
        }
        
        // 记录成功和失败的数量
        var successCount = 0
        var failureCount = 0
        
        // 依次处理每个账号
        for account in unprocessedAccounts {
            // 设置当前处理的账号ID
            await MainActor.run {
                currentProcessingAccountId = account.id
            }
            
            showToast("正在处理账号: \(account.username)...", type: .info)
            
            do {
                // 修改这里，使用返回值判断成功或失败
                let success = await processAccount(account, exchangeCount: exchangeCount)
                if success {
                    successCount += 1
                } else {
                    failureCount += 1
                }
                
                // 添加延迟，避免请求过于频繁
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒延迟
            } catch {
                print("账号处理发生异常: \(error.localizedDescription)")
                failureCount += 1
                showToast("账号 \(account.username) 处理失败：\(error.localizedDescription)", type: .error)
            }
        }
        
        // 添加额外的延迟确保所有异步操作完成
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延迟
        
        // 显示最终执行结果
        print("批量兑换完成，重置状态")
        await MainActor.run {
            showToast("批量兑换完成！成功：\(successCount)个，失败：\(failureCount)个", type: .info)
            isExecutingAll = false
            currentProcessingAccountId = nil
        }
    }
    
    // 添加新方法处理单个账号
    func processAccount(_ account: AccountInfo, exchangeCount: Int) async -> Bool {
        do {
            // 登录账号
            showToast("正在登录账号: \(account.username)...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)
            
            if !isValid || newToken == nil {
                showToast("账号 \(account.username) 登录失败", type: .error)
                return false
            }
            
            // 兑换停车券
            showToast("正在为账号 \(account.username) 兑换停车券...", type: .info)
            let orderNo = try await APIService.shared.exchangeVoucher(token: newToken!, count: exchangeCount)
            
            // 更新账号状态
            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.isProcessedToday = true
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accounts[index] = updatedAccount
                    saveAccounts()
                }
            }
            
            showToast("账号 \(account.username) 兑换成功，订单号: \(orderNo)", type: .success)
            
            // 刷新停车券数量
            showToast("正在刷新账号 \(account.username) 的停车券数量...", type: .info)
            let voucherCount = try await APIService.shared.getVoucherCount(token: newToken!)
            
            // 刷新积分
            showToast("正在刷新账号 \(account.username) 的积分...", type: .info)
            let bonus = try await APIService.shared.getBonus(token: newToken!)
            
            // 更新账号信息
            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.voucherCount = voucherCount
                    updatedAccount.bonus = bonus
                    accounts[index] = updatedAccount
                    saveAccounts()
                }
            }
            
            return true
        } catch {
            showToast("账号 \(account.username) 处理失败: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    // 修改批量导入账号的方法（如果有的话）
    func importAccounts(from accounts: [(username: String, password: String)]) async {
        for account in accounts {
            // 检查手机号是否已存在
            if !isPhoneNumberExists(account.username) {
                // 只添加不存在的账号
                _ = await addAccountWithValidation(username: account.username, password: account.password)
            } else {
                showToast("跳过重复的手机号：\(account.username)", type: .info)
            }
        }
    }
    
    // MARK: - 通知观察者
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .autoBackupTriggered,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.triggerAutoBackup()
            }
        }
    }
    
    @MainActor
    private func triggerAutoBackup() async {
        // 发送通知给 DataManager 进行自动备份
        NotificationCenter.default.post(
            name: .performAutoBackup,
            object: self.accounts
        )
    }
}

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()

    var fixedWidth: CGFloat = 1020
    var minHeight: CGFloat = 620
    var maxHeight: CGFloat = 1000

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let clampedHeight = min(max(frameSize.height, minHeight), maxHeight)
        return NSSize(width: fixedWidth, height: clampedHeight)
    }
}

// 添加一个WindowSetupModifier以控制窗口设置
struct WindowSetupModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 1020)
            .onAppear {
                setupMainWindow()
            }
    }
    
    private func setupMainWindow() {
        // 设置窗口位置和大小
        DispatchQueue.main.async {
            let window = NSApplication.shared.keyWindow
                ?? NSApplication.shared.mainWindow
                ?? NSApplication.shared.windows.first(where: { $0.isVisible })
                ?? NSApplication.shared.windows.first
            if let window {
                // 获取屏幕尺寸
                guard let screen = NSScreen.main else { return }
                let screenRect = screen.frame

                let fixedWidth: CGFloat = 1020
                let maxHeight = min(screenRect.height * 0.85, 1000)
                let minHeight: CGFloat = 620
                
                // 尽量按当前账号数量计算启动高度（账号少就完整显示，账号多就到上限并滚动）
                let accountsCount: Int
                if let data = UserDefaults.standard.data(forKey: "savedAccounts"),
                   let accounts = try? JSONDecoder().decode([AccountInfo].self, from: data) {
                    accountsCount = accounts.count
                } else {
                    accountsCount = 0
                }
                
                let columns = 3
                let rows = max(1, Int(ceil(Double(accountsCount) / Double(columns))))
                let estimatedCardHeight: CGFloat = 240
                let verticalSpacing: CGFloat = 12
                let verticalPadding: CGFloat = 16 * 2
                let chromeHeight: CGFloat = 180
                let estimatedHeight = chromeHeight
                    + verticalPadding
                    + CGFloat(rows) * estimatedCardHeight
                    + CGFloat(max(0, rows - 1)) * verticalSpacing
                let preferredHeight = min(max(minHeight, estimatedHeight), maxHeight)
                
                // 固定窗口宽度，只允许调整高度（防止布局变形）
                window.minSize = NSSize(width: fixedWidth, height: minHeight)
                window.maxSize = NSSize(width: fixedWidth, height: maxHeight)

                MainWindowDelegate.shared.fixedWidth = fixedWidth
                MainWindowDelegate.shared.minHeight = minHeight
                MainWindowDelegate.shared.maxHeight = maxHeight
                window.delegate = MainWindowDelegate.shared
                
                // 计算窗口大小（宽度固定，高度保持当前）
                let windowWidth = fixedWidth
                let windowHeight = preferredHeight
                
                // 计算居中位置
                let x = (screenRect.width - windowWidth) / 2
                let y = (screenRect.height - windowHeight) / 2
                
                // 设置窗口位置和大小
                window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
            }
        }
    }
}

// 扩展View以应用修饰符
extension View {
    func setupMainWindow() -> some View {
        self.modifier(WindowSetupModifier())
    }
}

struct ContentView: View {
    @StateObject private var accountManager = AccountManager()
    @StateObject private var dataManager = DataManager()
    @State private var showingAddAccount = false
    @State private var showingSettings = false
    @State private var showingPlateManager = false
    @State private var showOnlyUnprocessed = false
    @Environment(\.openWindow) private var openWindow
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 260, maximum: 360), spacing: 12, alignment: .top), count: 3)
    }

    private var unprocessedCount: Int {
        accountManager.accounts.filter { !$0.isProcessedToday }.count
    }

    private var totalVouchers: Int {
        accountManager.accounts.reduce(0) { partialResult, account in
            partialResult + account.voucherCount
        }
    }

    private var totalBonus: Int {
        accountManager.accounts.reduce(0) { partialResult, account in
            partialResult + account.bonus
        }
    }

    private var platesInQuickMenu: [String] {
        Array(dataManager.settings.licensePlates.prefix(8))
    }

    private var hasMorePlates: Bool {
        dataManager.settings.licensePlates.count > platesInQuickMenu.count
    }

    private var displayedAccounts: [AccountInfo] {
        if showOnlyUnprocessed {
            return accountManager.accounts.filter { !$0.isProcessedToday }
        }
        return accountManager.accounts
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Button {
                openWindow(id: "about")
            } label: {
                Label("About", systemImage: "info.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .help("关于")

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Label("账号 \(accountManager.accounts.count)", systemImage: "person.2")
                Label("积分 \(totalBonus)", systemImage: "star.fill")
                Label("停车券 \(totalVouchers)", systemImage: "ticket")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(NSColor.separatorColor).opacity(0.6)),
            alignment: .top
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if accountManager.accounts.isEmpty {
                    ContentUnavailableView(
                        "暂无账号",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("点击工具栏的“添加账号”开始使用")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if displayedAccounts.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text("全部已处理")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("当前已开启“仅未处理”过滤")
                            .foregroundColor(.secondary)

                        Button {
                            showOnlyUnprocessed = false
                        } label: {
                            Text("显示全部账号")
                                .frame(minWidth: 120)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(displayedAccounts) { account in
                                AccountRow(
                                    account: account,
                                    onDelete: {
                                        accountManager.deleteAccount(account: account)
                                    },
                                    onRefreshBonus: {
                                        Task {
                                            await accountManager.refreshBonus(for: account)
                                        }
                                    },
                                    onRefreshVoucher: {
                                        Task {
                                            await accountManager.refreshVoucherCount(for: account)
                                        }
                                    },
                                    onExchange: {
                                        Task {
                                            await accountManager.exchangeVoucher(for: account, exchangeCount: dataManager.settings.exchangeCount)
                                        }
                                    },
                                    accountManager: accountManager,
                                    dataManager: dataManager
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("花园城停车助手 V3.0")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Label("添加账号", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .help("添加账号")

                    Button {
                        showingSettings = true
                    } label: {
                        Label("设置", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
                    .help("设置")
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(platesInQuickMenu, id: \.self) { plate in
                                Button {
                                    dataManager.selectLicensePlate(plate)
                                } label: {
                                    if dataManager.settings.selectedLicensePlate == plate {
                                        Label(plate, systemImage: "checkmark")
                                    } else {
                                        Text(plate)
                                    }
                                }
                            }

                            if hasMorePlates {
                                Divider()
                                Button {
                                    showingPlateManager = true
                                } label: {
                                    Label("更多车牌号…", systemImage: "ellipsis")
                                }
                            }

                            Divider()

                            Button {
                                showingPlateManager = true
                            } label: {
                                Label("管理车牌号…", systemImage: "pencil")
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(dataManager.settings.selectedLicensePlate.isEmpty ? "车牌号" : dataManager.settings.selectedLicensePlate)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(minWidth: 160)
                        }
                        .help("选择车牌号")

                        Button {
                            showOnlyUnprocessed.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showOnlyUnprocessed ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                Text("仅未处理")
                            }
                            .font(.callout)
                            .foregroundColor(showOnlyUnprocessed ? .accentColor : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(showOnlyUnprocessed ? Color.accentColor.opacity(0.16) : Color(NSColor.controlBackgroundColor))
                            .clipShape(Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(showOnlyUnprocessed ? "已开启：仅显示未处理账号" : "开启：仅显示未处理账号")
                        .animation(.easeInOut(duration: 0.15), value: showOnlyUnprocessed)
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task {
                            await accountManager.executeAllAccounts(exchangeCount: dataManager.settings.exchangeCount)
                        }
                    } label: {
                        Label("一键执行", systemImage: "bolt.fill")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(accountManager.isExecutingAll || accountManager.accounts.isEmpty)
                    .help("一键执行")

                    Button {
                        accountManager.resetAllProcessedStatus()
                    } label: {
                        Label("重置状态", systemImage: "arrow.counterclockwise")
                            .labelStyle(.iconOnly)
                    }
                    .help("重置状态")
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView(isPresented: $showingAddAccount, accountManager: accountManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(dataManager: dataManager, accountManager: accountManager, isPresented: $showingSettings)
        }
        .sheet(isPresented: $showingPlateManager) {
            LicensePlateManagerView(dataManager: dataManager)
        }
        .overlay(alignment: .top) {
            if accountManager.showToast
                && !showingAddAccount
                && !showingSettings
                && !showingPlateManager {
                ToastView(message: accountManager.toastMessage, type: accountManager.toastType)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: accountManager.showToast)
                    .zIndex(999)
                    .allowsHitTesting(false)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            statusBar
        }
        .setupMainWindow()
        .onAppear {
            // 在应用启动时创建初始备份
            Task {
                await createInitialBackupIfNeeded()
            }
        }
    }
    
    // MARK: - 初始备份
    private func createInitialBackupIfNeeded() async {
        // 如果没有备份文件且有账号数据，创建初始备份
        if dataManager.backupFiles.isEmpty && !accountManager.accounts.isEmpty && !dataManager.settings.backupLocation.isEmpty {
            let success = await dataManager.createBackup(accounts: accountManager.accounts)
            if success {
                print("已创建初始备份")
            }
        }
    }
}

struct AddAccountView: View {
    @Binding var isPresented: Bool
    @StateObject var accountManager: AccountManager
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("添加新账号")
                .font(.title2)
                .fontWeight(.medium)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 16) {
                // 账号输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("账号")
                        .foregroundColor(.secondary)
                    TextField("请输入账号", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(height: 40)
                }
                
                // 密码输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("密码")
                        .foregroundColor(.secondary)
                    HStack {
                        if isPasswordVisible {
                            TextField("请输入密码", text: $password)
                        } else {
                            SecureField("请输入密码", text: $password)
                        }
                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(height: 40)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // 底部按钮
            HStack(spacing: 16) {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .frame(width: 100)
                
                Button(action: {
                    Task {
                        await loginAndAddAccount()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("添加")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 100)
                .disabled(username.isEmpty || password.isEmpty || isLoading)
            }
            .padding(.bottom)
        }
        .frame(width: 400, height: 300)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定") {
                if alertTitle == "登录成功" {
                    accountManager.addAccount(username: username, password: password)
                    isPresented = false
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func validateForm() -> Bool {
        // 清除之前的错误信息
        errorMessage = nil
        
        // 验证手机号格式
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        if username.isEmpty {
            errorMessage = "请输入手机号"
            return false
        }
        
        if !phoneTest.evaluate(with: username) {
            errorMessage = "请输入正确的手机号格式"
            return false
        }
        
        if password.isEmpty {
            errorMessage = "请输入密码"
            return false
        }
        
        // 检查手机号是否已存在
        if accountManager.isPhoneNumberExists(username) {
            errorMessage = "该手机号已存在，请勿重复添加"
            return false
        }
        
        return true
    }
    
    private func loginAndAddAccount() async {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (isValid, token, uid) = try await APIService.shared.login(username: username, password: password)
            
            if isValid && token != nil {
                accountManager.addAccount(username: username, password: password, token: token, uid: uid)
                isPresented = false
            } else {
                alertTitle = "登录失败"
                alertMessage = errorMessage ?? "未知错误"
                showingAlert = true
            }
        } catch {
            alertTitle = "错误"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isLoading = false
    }
}

struct AccountRow: View {
    let account: AccountInfo
    let onDelete: () -> Void
    let onRefreshBonus: () -> Void
    let onRefreshVoucher: () -> Void
    let onExchange: () -> Void
    @State private var isPasswordVisible = false
    @State private var isRefreshing = false
    @State private var showCopiedToast = false
    @State private var copiedText = ""
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var dataManager: DataManager
    @State private var showingDeleteConfirmation = false
    
    var isCurrentProcessing: Bool {
        accountManager.currentProcessingAccountId == account.id
    }

    private var statusText: String {
        account.isProcessedToday ? "已处理" : "未处理"
    }

    private var statusForegroundColor: Color {
        account.isProcessedToday ? .green : .orange
    }

    private var statusBackgroundColor: Color {
        account.isProcessedToday ? Color.green.opacity(0.12) : Color.orange.opacity(0.12)
    }

    private var cardStrokeColor: Color {
        isCurrentProcessing ? Color.accentColor.opacity(0.9) : Color(NSColor.separatorColor).opacity(0.55)
    }

    private var voucherCountColor: Color {
        if account.voucherCount == 0 {
            return .blue
        }
        if account.voucherCount <= 3 {
            return .primary
        }
        return .green
    }

    private var shouldHighlightParking: Bool {
        account.isProcessedToday && account.bonus > 0 && account.voucherCount > 0
    }

    private var parkingHighlightShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 10,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
    }

    private var parkingTitleColor: Color {
        shouldHighlightParking ? .accentColor : .primary
    }

    private var exchangeIconName: String {
        account.isProcessedToday ? "checkmark.circle.fill" : "checkmark"
    }

    private var exchangeIconColor: Color {
        account.isProcessedToday ? .white : .accentColor
    }

    private var exchangeHighlightShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 10,
            topTrailingRadius: 10
        )
    }

    @ViewBuilder
    private var exchangeHighlightBackground: some View {
        if account.isProcessedToday {
            exchangeHighlightShape
                .fill(Color.green.opacity(0.88))
        } else {
            exchangeHighlightShape
                .fill(Color.accentColor.opacity(0.12))
        }
    }

    @ViewBuilder
    private var exchangeHighlightOverlay: some View {
        exchangeHighlightShape
            .stroke((account.isProcessedToday ? Color.green : Color.accentColor).opacity(0.30), lineWidth: 1)
    }

    @ViewBuilder
    private var parkingHighlightBackground: some View {
        if shouldHighlightParking {
            parkingHighlightShape
                .fill(Color.accentColor.opacity(0.20))
        }
    }

    @ViewBuilder
    private var parkingHighlightOverlay: some View {
        if shouldHighlightParking {
            parkingHighlightShape
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
        }
    }
    
    private func openParkingDetails() {
        Task {
            do {
                // 先刷新登录状态获取新token
                let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)
                
                if !isValid || newToken == nil {
                    accountManager.showToast("登录失败，无法查看停车费", type: .error)
                    return
                }
                
                // 更新账号信息
                if let index = accountManager.accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accountManager.accounts[index]
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accountManager.accounts[index] = updatedAccount
                    accountManager.saveAccounts()
                }
                
                // 创建和显示窗口，添加关闭回调
                DispatchQueue.main.async {
                    let controller = WebViewWindowController(
                        account: AccountInfo(
                            username: account.username,
                            password: account.password,
                            token: newToken,
                            uid: uid
                        ),
                        dataManager: dataManager,
                        onClose: {
                            // 窗口关闭时刷新停车券数量
                            Task {
                                await self.accountManager.refreshVoucherCount(for: self.account)
                            }
                        }
                    )
                    // 保持对 controller 的强引用，直到窗口关闭
                    controller.window?.delegate = controller
                    controller.showWindow(nil)
                }
                
            } catch {
                accountManager.showToast("打开页面失败：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.username)
                        .font(.headline)
                        .onTapGesture {
                            copyToClipboard(account.username)
                            copiedText = "账号"
                            showCopiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedToast = false
                            }
                        }
                        .help("点击复制账号")

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("积分")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(account.bonus)")
                                        .font(.title3)
                                        .fontWeight(.semibold)

                                    Button(action: onRefreshBonus) {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.plain)
                                    .help("刷新积分")
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("停车券")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(account.voucherCount)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(voucherCountColor)

                                    Button(action: onRefreshVoucher) {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.plain)
                                    .help("刷新停车券")
                                }
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    if isCurrentProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .help("正在处理")
                    }

                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(statusForegroundColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(statusBackgroundColor.opacity(1.25))
                        .clipShape(Capsule(style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Button {
                            openParkingDetails()
                        } label: {
                            Label("查看停车", systemImage: "car.fill")
                                .labelStyle(.titleAndIcon)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundColor(parkingTitleColor)
                                .background(parkingHighlightBackground)
                                .overlay(parkingHighlightOverlay)
                        }
                        .buttonStyle(.plain)
                        .help("查看停车")

                        Divider()
                            .frame(height: 18)

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 44, height: 34)
                        }
                        .buttonStyle(.plain)
                        .help(isPasswordVisible ? "隐藏密码" : "查看密码")

                        Divider()
                            .frame(height: 18)

                        Button {
                            Task {
                                if account.isProcessedToday {
                                    accountManager.showToast("该账号今天已处理", type: .info)
                                    return
                                }
                                await onExchange()
                            }
                        } label: {
                            Image(systemName: exchangeIconName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(exchangeIconColor)
                                .frame(width: 44, height: 34)
                                .background(exchangeHighlightBackground)
                                .overlay(exchangeHighlightOverlay)
                        }
                        .buttonStyle(.plain)
                        .help(account.isProcessedToday ? "该账号今天已处理" : "兑换")
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
                    )

                    Spacer(minLength: 8)

                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("删除该账号")
                    .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("删除", role: .destructive) {
                            onDelete()
                        }
                    } message: {
                        Text("确定要删除账号 \(account.username) 吗？此操作不可撤销。")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isPasswordVisible {
                    Text(account.password)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onTapGesture {
                            copyToClipboard(account.password)
                            copiedText = "密码"
                            showCopiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedToast = false
                            }
                        }
                        .help("点击复制密码")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: isCurrentProcessing ? 2 : 1)
        )
        .overlay(
            Group {
                if showCopiedToast {
                    Text("\(copiedText)已复制")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Capsule(style: .continuous))
                        .transition(.opacity)
                        .padding(.top, 8)
                }
            },
            alignment: .top
        )
        .animation(.easeInOut, value: showCopiedToast)
    }
    
    // 添加复制到剪贴板的辅助函数
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// 添加 Toast 视图组件
struct ToastView: View {
    let message: String
    let type: AccountManager.ToastType
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .foregroundColor(.white)
            Text(message)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.backgroundColor)
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

// 修改 WebViewWindowController
class WebViewWindowController: NSWindowController, NSWindowDelegate {
    private var coordinator: WebViewCoordinator
    private let account: AccountInfo
    private let dataManager: DataManager
    private var webView: WKWebView
    private var isClosing = false // 添加标志防止重复关闭
    private var onClose: (() -> Void)? // 添加关闭回调
    
    init(account: AccountInfo, dataManager: DataManager, onClose: (() -> Void)? = nil) {
        self.account = account
        self.dataManager = dataManager
        self.coordinator = WebViewCoordinator()
        self.webView = WKWebView(frame: .zero)
        self.onClose = onClose
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430 * 0.8, height: 932 * 0.8),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        // 配置窗口
        window.delegate = self
        window.title = "停车费详情"
        window.center()
        
        // 配置 WebView
        webView.navigationDelegate = coordinator
        coordinator.webView = webView
        
        // 设置拦截器
        coordinator.setupInterception(selectedMaxCount: dataManager.settings.selectedMaxCount)
        
        // 设置 cookies
        let cookies = createCookies(for: account)
        cookies.forEach { cookie in
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }
        
        // 创建请求，使用选中的车牌号
        let encodedPlate = dataManager.getEncodedSelectedLicensePlate()
        let parkingURL = "https://m-bms.cmsk1979.com/v/park/parkFee/feeDetails?pid=1256&plate=\(encodedPlate)&barcode=&carInputType=0&mid=11992"
        let url = URL(string: parkingURL)!
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com/", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        webView.load(request)
        
        // 创建主视图容器，添加新按钮
        let hostingView = NSHostingView(rootView: 
            VStack {
                HStack {
                    // 添加复制链接按钮
                    Button(action: {
                        self.copyURL(parkingURL)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                            .help("复制链接")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    
                    // 添加在浏览器中打开按钮
                    Button(action: {
                        self.openInBrowser(url)
                    }) {
                        Image(systemName: "safari")
                            .foregroundColor(.green)
                            .imageScale(.large)
                            .help("在浏览器中打开")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    
                    Spacer()
                    
                    // 原有的关闭按钮
                    Button(action: {
                        self.closeWindow()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .imageScale(.large)
                            .help("关闭窗口")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                WebViewWrapper(webView: webView)
            }
        )
        
        window.contentView = hostingView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func closeWindow() {
        // 防止重复关闭
        guard !isClosing else { return }
        isClosing = true
        
        print("WindowController: 开始关闭窗口...")
        
        // 先停止加载
        webView.stopLoading()
        
        // 清理 WebView
        coordinator.cleanupWebView()
        
        // 关闭窗口
        DispatchQueue.main.async {
            self.window?.close()
            print("WindowController: 窗口已关闭")
            
            // 调用关闭回调
            self.onClose?()
        }
    }
    
    // NSWindowDelegate 方法
    func windowWillClose(_ notification: Notification) {
        print("WindowController: 窗口即将关闭")
        closeWindow()
    }
    
    deinit {
        print("WindowController: 开始释放")
        // 移除 deinit 中的 closeWindow 调用，因为 windowWillClose 会处理
        print("WindowController: 释放完成")
    }
    
    private func createCookies(for account: AccountInfo) -> [HTTPCookie] {
        let cookieProperties: [[HTTPCookiePropertyKey: Any]] = [
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_token",
             .value: account.token ?? "",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_uid",
             .value: account.uid ?? "",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_uuid",
             .value: "768ccf7d4c29df0ba4ac9267aedf1a83",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_mid",
             .value: "11992",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_mobile",
             .value: account.username,
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_userInfo",
             .value: "mobile%3D\(account.username)",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_bussinessSrc",
             .value: "%7B%22BusinessSourceID%22%3A5%7D",
             .secure: true]
        ]
        
        return cookieProperties.compactMap { HTTPCookie(properties: $0) }
    }
    
    // 添加复制URL到剪贴板的方法
    private func copyURL(_ urlString: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urlString, forType: .string)
        
        // 可选：显示复制成功的反馈
        if let window = self.window {
            let alert = NSAlert()
            alert.messageText = "链接已复制到剪贴板"
            alert.informativeText = urlString
            alert.addButton(withTitle: "确定")
            alert.beginSheetModal(for: window) { _ in }
        }
    }
    
    // 添加在默认浏览器中打开URL的方法
    private func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

// WebViewCoordinator 添加拦截和修改网络响应的功能
class WebViewCoordinator: NSObject, WKNavigationDelegate, ObservableObject {
    weak var webView: WKWebView?
    
    // 在 webView 设置后添加拦截脚本
    func setupInterception(selectedMaxCount: Int) {
        guard let webView = webView else { return }
        
        // 创建拦截 XHR 响应的 JavaScript 脚本
        let script = """
        (function() {
            let originalOpen = XMLHttpRequest.prototype.open;
            let originalSend = XMLHttpRequest.prototype.send;
            
            XMLHttpRequest.prototype.open = function(method, url) {
                this._url = url;
                return originalOpen.apply(this, arguments);
            };
            
            XMLHttpRequest.prototype.send = function() {
                let xhr = this;
                let originalOnReadyStateChange = xhr.onreadystatechange;
                
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                        // 当响应完成时
                        try {
                            let responseText = xhr.responseText;
                            if (responseText && responseText.includes('"SelectedMaxCount":')) {
                                // 替换 SelectedMaxCount 值
                                let modifiedResponse = responseText.replace(/"SelectedMaxCount":\\d+/g, '"SelectedMaxCount":\(selectedMaxCount)');
                                Object.defineProperty(xhr, 'responseText', { value: modifiedResponse });
                                console.log('已修改响应体中的 SelectedMaxCount 为 \(selectedMaxCount)');
                            }
                        } catch (e) {
                            console.error('修改响应失败:', e);
                        }
                    }
                    
                    if (originalOnReadyStateChange) {
                        originalOnReadyStateChange.apply(xhr, arguments);
                    }
                };
                
                return originalSend.apply(this, arguments);
            };
        })();
        """
        
        // 创建用户脚本并添加到 WebView 配置中
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        webView.configuration.userContentController.addUserScript(userScript)
        print("已添加响应拦截脚本")
    }
    
    func cleanupWebView() {
        print("Coordinator: 开始清理 WebView...")
        
        // 停止所有加载和请求
        webView?.stopLoading()
        print("Coordinator: 已停止加载")
        
        // 清理所有正在进行的请求
        webView?.configuration.processPool = WKProcessPool()
        print("Coordinator: 已重置进程池")
        
        // 从父视图中移除
        DispatchQueue.main.async { [weak self] in
            self?.webView?.removeFromSuperview()
            print("Coordinator: 已从父视图移除")
        }
        
        // 清理 delegate
        webView?.navigationDelegate = nil
        print("Coordinator: 已清理 delegate")
        
        // 清理 WKWebView
        webView?.configuration.userContentController.removeAllUserScripts()
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        print("Coordinator: 已清理 WebView 配置")
        
        // 清理 cookies 和其他数据
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { 
            print("Coordinator: 已清理所有网站数据")
        }
        
        // 将 webView 设置为 nil
        webView = nil
        print("Coordinator: WebView 清理完成")
    }
    
    deinit {
        print("Coordinator: 被释放")
        cleanupWebView()
    }
}

// 新增 WebViewWrapper 结构体
struct WebViewWrapper: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 不需要实现任何更新逻辑
    }
}

