// Purpose: ViewModel for settings-related async operations (gift discovery and gift list fetching).
// Author: Achord <achordchan@gmail.com>
import Foundation

final class SettingsViewModel: ObservableObject {
    @Published var isDiscoveringGift: Bool = false
    @Published var isFetchingGiftList: Bool = false
    @Published var parkingVoucherGifts: [APIService.GiftInfoListItem] = []

    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
    }

    func fetchParkingVoucherGifts(dataManager: DataManager, accountManager: AccountManager) async {
        let context: (accounts: [AccountInfo], exchangeMid: String)? = await MainActor.run {
            guard !isFetchingGiftList else { return nil }
            guard !accountManager.accounts.isEmpty else {
                accountManager.showToast("请先添加账号，再拉取礼品列表", type: .info)
                return nil
            }

            isFetchingGiftList = true
            parkingVoucherGifts = []
            return (accountManager.accounts, dataManager.settings.exchangeMid)
        }

        guard let context else { return }

        defer {
            Task { @MainActor in
                self.isFetchingGiftList = false
            }
        }

        do {
            var resolvedToken: String?
            var resolvedUid: String?
            var lastLoginError: String?

            for account in context.accounts {
                do {
                    let (isValid, token, uid) = try await apiService.login(
                        username: account.username,
                        password: account.password
                    )

                    if isValid, let token {
                        resolvedToken = token
                        resolvedUid = uid
                        break
                    } else {
                        lastLoginError = "账号 \(account.username) 登录失败"
                    }
                } catch let apiError as APIService.APIError {
                    lastLoginError = apiError.message
                } catch {
                    lastLoginError = error.localizedDescription
                }
            }

            guard let rawToken = resolvedToken else {
                await MainActor.run {
                    if let lastLoginError {
                        accountManager.showToast("登录失败，无法拉取：\(lastLoginError)", type: .error)
                    } else {
                        accountManager.showToast("登录失败，无法拉取", type: .error)
                    }
                }
                return
            }

            let tokenForGiftList: String
            if rawToken.contains(",") {
                tokenForGiftList = rawToken
            } else if let uid = resolvedUid, !uid.isEmpty {
                tokenForGiftList = "\(rawToken),\(uid)"
            } else {
                tokenForGiftList = rawToken
            }

            let gifts = try await apiService.getGiftInfoList(token: tokenForGiftList, mid: context.exchangeMid)
            let parkingVouchers = gifts.filter { $0.n.contains("停车券") }

            await MainActor.run {
                parkingVoucherGifts = parkingVouchers
                if parkingVouchers.isEmpty {
                    accountManager.showToast("未找到停车券礼品", type: .info)
                } else {
                    accountManager.showToast("已拉取 \(parkingVouchers.count) 个停车券礼品", type: .success)
                }
            }
        } catch let apiError as APIService.APIError {
            await MainActor.run {
                accountManager.showToast("拉取失败：\(apiError.message)", type: .error)
            }
        } catch {
            await MainActor.run {
                accountManager.showToast("拉取失败：\(error.localizedDescription)", type: .error)
            }
        }
    }

    func discoverParkingVoucherGift(dataManager: DataManager, accountManager: AccountManager) async {
        let context: (accounts: [AccountInfo], exchangeMid: String)? = await MainActor.run {
            guard !isDiscoveringGift else { return nil }
            guard !accountManager.accounts.isEmpty else {
                accountManager.showToast("请先添加账号，再进行自动识别", type: .info)
                return nil
            }

            isDiscoveringGift = true
            return (accountManager.accounts, dataManager.settings.exchangeMid)
        }

        guard let context else { return }

        defer {
            Task { @MainActor in
                self.isDiscoveringGift = false
            }
        }

        do {
            var resolvedToken: String?
            var resolvedUid: String?
            var lastLoginError: String?

            for account in context.accounts {
                do {
                    let (isValid, token, uid) = try await apiService.login(
                        username: account.username,
                        password: account.password
                    )

                    if isValid, let token {
                        resolvedToken = token
                        resolvedUid = uid
                        break
                    } else {
                        lastLoginError = "账号 \(account.username) 登录失败"
                    }
                } catch let apiError as APIService.APIError {
                    lastLoginError = apiError.message
                } catch {
                    lastLoginError = error.localizedDescription
                }
            }

            guard let rawToken = resolvedToken else {
                await MainActor.run {
                    if let lastLoginError {
                        accountManager.showToast("登录失败，无法识别：\(lastLoginError)", type: .error)
                    } else {
                        accountManager.showToast("登录失败，无法识别", type: .error)
                    }
                }
                return
            }

            let tokenForGiftList: String
            if rawToken.contains(",") {
                tokenForGiftList = rawToken
            } else if let uid = resolvedUid, !uid.isEmpty {
                tokenForGiftList = "\(rawToken),\(uid)"
            } else {
                tokenForGiftList = rawToken
            }

            let gift = try await apiService.discoverParkingVoucherGift(
                token: tokenForGiftList,
                mid: context.exchangeMid
            )

            await MainActor.run {
                dataManager.settings.exchangeGid = String(gift.id)
                dataManager.saveSettings()
                accountManager.showToast("已识别：\(gift.n)（gid=\(gift.id)）", type: .success)
            }
        } catch let apiError as APIService.APIError {
            await MainActor.run {
                accountManager.showToast("识别失败：\(apiError.message)", type: .error)
            }
        } catch {
            await MainActor.run {
                accountManager.showToast("识别失败：\(error.localizedDescription)", type: .error)
            }
        }
    }
}
