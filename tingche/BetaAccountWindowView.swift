// Purpose: Beta window UI for future phone-number acquisition and cross-city points workflow.
// Author: Achord <achordchan@gmail.com>
import AppKit
import SwiftUI

struct BetaAccountWindowView: View {
    @AppStorage("beta.autoAddOneClickAccounts") private var autoAddOneClickAccounts = false
    @StateObject private var dataManager = DataManager()
    @StateObject private var accountManager = AccountManager()
    @State private var selectedMode: BetaWindowMode = .simple
    @State private var selectedSeedCity = "深圳招商蛇口"
    @State private var selectedExpansionCity = "全部可提交商场"
    @State private var selectedCarrier = "不限"
    @State private var selectedProvince = "不限"
    @State private var selectedCardType = "不限"
    @State private var isLoggingIn = false
    @State private var isRefreshingSummary = false
    @State private var isGettingPhone = false
    @State private var isPollingCode = false
    @State private var isReleasingPhone = false
    @State private var isBlacklistingPhone = false
    @State private var shouldStopPolling = false
    @State private var accountBalance = "--"
    @State private var maxAreaCount = "--"
    @State private var currentPhone = "待获取"
    @State private var currentPhoneMeta = "运营商/归属地：待返回"
    @State private var currentCode = "待获取"
    @State private var currentSMS = "短信内容：待返回"
    @State private var isRegisteringSeedCity = false
    @State private var seedCityToken = "待获取"
    @State private var seedCityUID = "待获取"
    @State private var seedCityBonus = "待确认"
    @State private var seedCityUserName = "待生成"
    @State private var seedCityProjectType = "待获取"
    @State private var isRunningExpansionTask = false
    @State private var expansionTaskStatus = "未执行"
    @State private var expansionTaskBonus = "待统计"
    @State private var expansionTaskEmail = "待生成"
    @State private var expansionTaskAddress = "待生成"
    @State private var isLoadingBonusHistory = false
    @State private var bonusHistoryTotal = "待查询"
    @State private var bonusHistoryItems: [BonusHistoryItem] = []
    @State private var isLoadingZhanjiangGraphic = false
    @State private var isSendingZhanjiangSMS = false
    @State private var zhanjiangGraphicImageURL = ""
    @State private var zhanjiangGraphicPreview: NSImage?
    @State private var zhanjiangGraphicKeyword = ""
    @State private var zhanjiangGraphicCodeInput = ""
    @State private var zhanjiangTargetPhone = ""
    @State private var zhanjiangSMSStatus = "未开始"
    @State private var zhanjiangReceivedCode = "待获取"
    @State private var zhanjiangReceivedSMS = "短信内容：待返回"
    @State private var zhanjiangSMSFailureReason = ""
    @State private var isUpdatingZhanjiangPassword = false
    @State private var zhanjiangPasswordStatus = "未提交"
    @State private var zhanjiangFixedPassword = "qwer1234"
    @State private var isRunningOneClick = false
    @State private var oneClickStepStates = OneClickFlowStep.defaultStates
    @State private var oneClickResults: [OneClickAccountResult] = []
    @State private var showingCaptchaSheet = false
    @State private var showingManualSMSCodeSheet = false
    @State private var oneClickPulse = false
    @State private var selectedOneClickPhoneSource: OneClickPhoneSource = .haozhu
    @State private var manualOneClickPhone = ""
    @State private var manualSMSCodeStage: ManualSMSCodeStage = .seedRegister(phoneNumber: "")
    @State private var manualSMSCodeInput = ""
    @State private var runtimeLogs: [BetaRuntimeLog] = []
    @State private var phoneRecords: [BetaPhoneRecord] = []
    @State private var selectedPhoneIDs: Set<String> = []
    @State private var statusMessage = "请先登录豪猪，拿到 token 后再继续取号。"
    @State private var statusTone: BetaStatusTone = .info
    @State private var oneClickFlowTask: Task<Void, Never>?
    @State private var messagePollingTask: Task<Void, Never>?
    private let oneClickResultsStorageKey = "beta.oneClickResults"

    private let workflowSteps: [BetaWorkflowStep] = [
        .init(
            title: "获取接码手机号",
            detail: "按短信签名筛选豪猪接码号码，拿到可接收验证码的手机号。",
            systemImage: "simcard"
        ),
        .init(
            title: "完成首城注册",
            detail: "基于你后续提供的城市接口，发验证码、注册并领取新用户积分。",
            systemImage: "building.2.crop.circle"
        ),
        .init(
            title: "复用 Token 执行扩城",
            detail: "拿到 token 后，继续批量跑所有可提交商场的资料完善任务。",
            systemImage: "point.3.connected.trianglepath.dotted"
        )
    ]

    private let executionLogs: [String] = [
        "等待接入豪猪接码接口文档。",
        "等待首个城市注册接口参数与签名规则。",
        "等待其他城市资料完善接口定义。"
    ]

    private let lineOptions = [
        "https://api.haozhuma.com",
        "https://api.haozhuyun.com"
    ]
    private let seedCityOptions = ["深圳招商蛇口"]
    private let expansionCityOptions = ["全部可提交商场", "深圳海上世界", "赣州招商", "三亚崖州"]
    private let carrierOptions = ["不限", "中国移动", "中国联通", "中国电信"]
    private let provinceOptions = ["不限", "广东", "江苏", "上海", "浙江"]
    private let cardTypeOptions = ["不限", "虚拟号", "实卡"]
    private let shenzhenMallID = 11026
    private let shenzhenBusinessSourceID = "16"
    private let shenzhenBusinessSourceData = ""
    private let shenzhenLightUID = "5c2b7ab19cff476e9302f6975309bca9"
    private let shenzhenWechatOpenID = "oXCuFjuiSUD1fUH_HLHJCini5jvE"
    private let shenzhenMiniOpenID = "okZUd5BXnY0sJEZWGIypBnkNi0_g"
    private let shenzhenMiniUnionID = "undefined"
    private let shenzhenBirthday = "1985-01-01"
    private let shenzhenRemark1 = "南山蛇口"
    private let shenzhenGender = "1"
    private let shenzhenHaiShangWorldMallID = 11027
    private let ganzhouMallID = 12073
    private let sanyaYazhouMallID = 12649
    private let bonusHistoryMallID = 12350
    private let zhanjiangMallID = 12350
    private let ganzhouFixedIDNumber = "131121200007099415"
    private let ganzhouFixedAge = "41"
    private let allMallBatchTargets: [BatchMallSubmissionTarget] = [
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

    private var normalizedServerURL: String {
        let raw = dataManager.settings.betaHaozhuServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    }

    private var hasLoginConfig: Bool {
        !normalizedServerURL.isEmpty
            && !dataManager.settings.betaHaozhuAPIUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !dataManager.settings.betaHaozhuAPIPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasToken: Bool {
        !dataManager.settings.betaHaozhuToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasCurrentPhone: Bool {
        let phone = currentPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        return !phone.isEmpty && phone != "待获取"
    }

    private var isOneClickUsingSelfPhone: Bool {
        selectedOneClickPhoneSource == .selfManaged
    }

    private var normalizedManualOneClickPhone: String {
        manualOneClickPhone.filter(\.isNumber)
    }

    private var currentVerificationCode: String? {
        extractVerificationCode(from: currentCode, fallback: currentSMS)
    }

    private var hasUsableSeedCityToken: Bool {
        let token = seedCityToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return !token.isEmpty
            && token != "待获取"
            && token != "注册失败"
            && token != "注册中..."
            && token.contains(",")
    }

    private var zhanjiangVerificationCode: String? {
        extractVerificationCode(from: zhanjiangReceivedCode, fallback: zhanjiangReceivedSMS)
    }

    private var normalizedZhanjiangGraphicImageURL: String {
        normalizedGraphicImageURL(zhanjiangGraphicImageURL)
    }

    private var canGetPhone: Bool {
        hasToken && !dataManager.settings.betaHaozhuProjectID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canGetMessage: Bool {
        canGetPhone && hasCurrentPhone
    }

    private var canManageCurrentPhone: Bool {
        canGetMessage && !isGettingPhone
    }

    private var canStartOneClickFlow: Bool {
        guard !isRunningOneClick else { return false }
        if isOneClickUsingSelfPhone {
            return normalizedManualOneClickPhone.count == 11
        }
        return hasLoginConfig && !dataManager.settings.betaHaozhuProjectID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedManageablePhones: [BetaPhoneRecord] {
        phoneRecords.filter { selectedPhoneIDs.contains($0.id) && $0.canManage }
    }

    private var hasSelectedPhones: Bool {
        !selectedManageablePhones.isEmpty
    }

    private var canStartSeedRegistration: Bool {
        selectedSeedCity == "深圳招商蛇口"
            && hasCurrentPhone
            && !isRegisteringSeedCity
    }

    private var canStartExpansionTask: Bool {
        expansionCityOptions.contains(selectedExpansionCity)
            && hasUsableSeedCityToken
            && !isRunningExpansionTask
    }

    private var canLoadBonusHistory: Bool {
        hasUsableSeedCityToken && !isLoadingBonusHistory
    }

    private var canLoadZhanjiangGraphic: Bool {
        hasUsableSeedCityToken && !isLoadingZhanjiangGraphic
    }

    private var canSendZhanjiangSMS: Bool {
        hasUsableSeedCityToken
            && !(zhanjiangTargetPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && !zhanjiangGraphicKeyword.isEmpty
            && !zhanjiangGraphicCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSendingZhanjiangSMS
    }

    private var canUpdateZhanjiangPassword: Bool {
        hasUsableSeedCityToken
            && !(zhanjiangTargetPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && zhanjiangVerificationCode != nil
            && !zhanjiangGraphicKeyword.isEmpty
            && !zhanjiangGraphicCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isUpdatingZhanjiangPassword
    }

    private var maskedToken: String {
        let token = dataManager.settings.betaHaozhuToken
        guard token.count > 16 else { return token.isEmpty ? "--" : token }
        return "\(token.prefix(8))...\(token.suffix(8))"
    }

    private var smsSignatureBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.betaSMSReceiverSignature },
            set: { newValue in
                dataManager.settings.betaSMSReceiverSignature = newValue
                dataManager.saveSettings()
            }
        )
    }

    private var serverURLBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.betaHaozhuServerURL },
            set: { newValue in
                dataManager.settings.betaHaozhuServerURL = newValue
                dataManager.saveSettings()
            }
        )
    }

    private var apiUserBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.betaHaozhuAPIUser },
            set: { newValue in
                dataManager.settings.betaHaozhuAPIUser = newValue
                dataManager.saveSettings()
            }
        )
    }

    private var apiPasswordBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.betaHaozhuAPIPassword },
            set: { newValue in
                dataManager.settings.betaHaozhuAPIPassword = newValue
                dataManager.saveSettings()
            }
        )
    }

    private var tokenBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.betaHaozhuToken },
            set: { newValue in
                dataManager.settings.betaHaozhuToken = newValue
                dataManager.saveSettings()
            }
        )
    }

    private var projectIDBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.betaHaozhuProjectID },
            set: { newValue in
                dataManager.settings.betaHaozhuProjectID = newValue
                dataManager.saveSettings()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                modeSwitcher

                if selectedMode == .simple {
                    simpleFlowCard
                    simpleResultListCard
                } else {
                    accountCard
                    configurationCard
                    zhanjiangPasswordCard
                    workflowCard
                    resultCard
                    phonePoolCard
                    logCard
                }
            }
            .padding(20)
        }
        .frame(minWidth: 840, idealWidth: 920, maxWidth: 1080, minHeight: 620, idealHeight: 760)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.10),
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            if runtimeLogs.isEmpty {
                runtimeLogs = executionLogs.map { BetaRuntimeLog(level: .info, message: $0) }
            }
            loadOneClickResults()
        }
        .onChange(of: statusMessage) { _, newValue in
            appendRuntimeLog(message: newValue, level: statusTone)
        }
        .onChange(of: oneClickResults) { _, _ in
            saveOneClickResults()
        }
        .sheet(isPresented: $showingCaptchaSheet) {
            oneClickCaptchaSheet
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingManualSMSCodeSheet) {
            manualSMSCodeSheet
                .interactiveDismissDisabled()
        }
        .onAppear {
            oneClickPulse = true
        }
        .onDisappear {
            cancelLongRunningTasks()
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 12) {
            Picker("模式", selection: $selectedMode) {
                ForEach(BetaWindowMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            Text(selectedMode == .simple ? "面向普通用户的一键流程，只保留节点进度、必要弹窗和结果列表。" : "保留全部调试控件，适合联调、排障和单步执行。")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    private var simpleFlowCard: some View {
        GroupBox(label: Label("一键获得账号", systemImage: "sparkles")) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("接码方式")
                            .font(.subheadline.weight(.semibold))

                        Picker("接码方式", selection: $selectedOneClickPhoneSource) {
                            ForEach(OneClickPhoneSource.allCases, id: \.self) { source in
                                Text(source.rawValue).tag(source)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)

                        Spacer()
                    }

                    if isOneClickUsingSelfPhone {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("请输入你自己的手机号", text: $manualOneClickPhone)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 240)

                            Text("不会再登录豪猪，也不会自动取号或拉黑。深圳注册验证码和湛江改密验证码都由你自己查看手机后手动输入。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("继续沿用豪猪接码，流程会自动取号、自动二次接码，并在结束后自动拉黑本轮号码。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("普通用户模式")
                            .font(.title3.weight(.bold))
                        Text(
                            isOneClickUsingSelfPhone
                            ? "点击一次开始，流程会自动完成首城注册、批量刷商场提交、刷新积分展示和最终改密。短信验证码改为你自己手动输入。"
                            : "点击一次开始，流程会自动完成取号、注册、批量刷商场提交、刷新积分展示和最终改密。遇到图形验证码时会强制弹窗让用户输入。"
                        )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Button(isRunningOneClick ? "执行中..." : "一键获得账号") {
                            startOneClickFlowTask()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canStartOneClickFlow)

                        Text("当前状态：\(statusMessage)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 280, alignment: .trailing)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(OneClickFlowStep.allCases) { step in
                        oneClickStepRow(step)
                    }
                }
            }
        }
    }

    private func oneClickStepRow(_ step: OneClickFlowStep) -> some View {
        let state = oneClickStepStates[step] ?? .pending
        let isActive = state == .running

        return HStack(spacing: 14) {
            Circle()
                .fill(state.color.opacity(isActive ? 0.95 : 0.8))
                .frame(width: 14, height: 14)
                .scaleEffect(isActive && oneClickPulse ? 1.25 : 1.0)
                .animation(
                    isActive
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.2),
                    value: oneClickPulse
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title(for: selectedOneClickPhoneSource))
                    .font(.headline)
                Text(state.detailText(for: step, phoneSource: selectedOneClickPhoneSource))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Label(state.title, systemImage: state.icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(state.color)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var simpleResultListCard: some View {
        GroupBox(label: Label("已获得账号", systemImage: "list.bullet.rectangle")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("完成后的账号会出现在这里，可直接加入主程序号码池。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Toggle("新号码自动加入主程序", isOn: $autoAddOneClickAccounts)
                        .toggleStyle(.checkbox)
                    Button("全部加入主程序号码池") {
                        Task {
                            await addAllOneClickResultsToPool()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(oneClickResults.isEmpty || oneClickResults.allSatisfy(\.addedToPool))
                }

                if oneClickResults.isEmpty {
                    Text("还没有已完成账号。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 28)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(oneClickResults) { result in
                            oneClickResultRow(result)
                        }
                    }
                }
            }
        }
    }

    private func oneClickResultRow(_ result: OneClickAccountResult) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.phone)
                    .font(.system(.headline, design: .monospaced))
                Text("密码：\(result.password)  积分：\(result.bonusText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(result.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Label(result.status.rawValue, systemImage: result.status.icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(result.status.color)

            Button(result.addedToPool ? "已加入" : "加入主程序号码池") {
                Task {
                    await addOneClickResultToPool(result.id)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(result.addedToPool)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var oneClickCaptchaSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("请输入图形验证码")
                .font(.title2.weight(.bold))

            Text("流程已暂停，必须先输入湛江图形验证码，之后会自动继续发送短信、二次接码并完成改密。")
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    if let preview = zhanjiangGraphicPreview {
                        Image(nsImage: preview)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 180, height: 84)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Text("图形验证码尚未加载成功")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 180, height: 84)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Text(normalizedZhanjiangGraphicImageURL.isEmpty ? "图像地址：待获取" : normalizedZhanjiangGraphicImageURL)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("请输入图中的验证码", text: $zhanjiangGraphicCodeInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)

                    Text("目标手机号：\(zhanjiangTargetPhone)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("继续执行") {
                        showingCaptchaSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(zhanjiangGraphicCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private var manualSMSCodeSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(manualSMSCodeStage.title)
                .font(.title2.weight(.bold))

            Text(manualSMSCodeStage.prompt)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("目标手机号：\(manualSMSCodeStage.phoneNumber)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)

                TextField("请输入收到的短信验证码", text: $manualSMSCodeInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }

            HStack(spacing: 12) {
                Button("取消本轮") {
                    manualSMSCodeInput = ""
                    showingManualSMSCodeSheet = false
                }
                .buttonStyle(.bordered)

                Button("继续执行") {
                    showingManualSMSCodeSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(manualSMSCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var headerCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("获取账号（Beta）")
                            .font(.system(size: 28, weight: .bold))
                        Text(selectedMode == .simple ? "普通用户只保留一键流程；专业模式继续承担联调和故障排查。" : "专业模式保留全部接码、注册、扩城和改密控件。")
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("Beta")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.gradient)
                        .clipShape(Capsule(style: .continuous))
                }

                HStack(spacing: 12) {
                    betaMetric(title: "当前阶段", value: "已接登录")
                    betaMetric(title: "接码平台", value: "豪猪")
                    betaMetric(title: "多城市任务", value: "待联调")
                }
            }
        }
    }

    private var accountCard: some View {
        GroupBox(label: Label("豪猪账号信息", systemImage: "person.crop.rectangle")) {
            VStack(alignment: .leading, spacing: 14) {
                if hasToken {
                    loggedInAccountContent
                } else {
                    loggedOutAccountContent
                }

                HStack(spacing: 12) {
                    betaMetric(title: "登录接口", value: "login")
                    betaMetric(title: "账号信息接口", value: "getSummary")
                    betaMetric(title: "余额 / 区号数", value: "\(accountBalance) / \(maxAreaCount)")
                }

                Text("当前接码号码：\(currentPhone)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(currentPhone == "待获取" ? .secondary : .primary)

                statusBanner

                HStack(spacing: 10) {
                    if hasToken {
                        Button(isRefreshingSummary ? "刷新中..." : "刷新账号信息") {
                            Task {
                                await refreshSummary()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRefreshingSummary)

                        Button("退出登录") {
                            logoutHaozhu()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(isLoggingIn ? "登录中..." : "登录获取 Token") {
                            Task {
                                await loginToHaozhu()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasLoginConfig || isLoggingIn)
                    }

                    Spacer()

                    Text(hasToken ? "已登录后仅保留账号信息展示；点击退出登录可重新显示登录表单。" : "已填好服务器、账号、密码后，登录按钮会自动亮起。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var loggedOutAccountContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("服务器地址")
                        .font(.headline)
                    TextField("例如：https://api.haozhuma.com", text: serverURLBinding)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("API 账号")
                        .font(.headline)
                    TextField("输入 API 账号", text: apiUserBinding)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 10) {
                ForEach(lineOptions, id: \.self) { line in
                    Button {
                        dataManager.settings.betaHaozhuServerURL = line
                        dataManager.saveSettings()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: dataManager.settings.betaHaozhuServerURL == line ? "checkmark.circle.fill" : "circle")
                            Text(line.replacingOccurrences(of: "https://", with: ""))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            dataManager.settings.betaHaozhuServerURL == line
                            ? Color.accentColor.opacity(0.14)
                            : Color(NSColor.controlBackgroundColor)
                        )
                        .clipShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("当前实测优先：api.haozhuma.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API 密码")
                        .font(.headline)
                    SecureField("输入 API 密码", text: apiPasswordBinding)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("项目 ID")
                        .font(.headline)
                    TextField("登录后用于取号，例如 sid", text: projectIDBinding)
                        .textFieldStyle(.roundedBorder)
                    Text("项目 ID 就是豪猪接口里的 `sid`，表示具体接码项目编号。不是登录账号；后续取号和取验证码都要带它。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var loggedInAccountContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                betaMetric(title: "服务器地址", value: normalizedServerURL.replacingOccurrences(of: "https://", with: ""))
                betaMetric(title: "API 账号", value: dataManager.settings.betaHaozhuAPIUser)
                betaMetric(title: "项目 ID", value: dataManager.settings.betaHaozhuProjectID)
            }

            HStack(spacing: 12) {
                betaMetric(title: "Token", value: maskedToken)
                betaMetric(title: "当前号码", value: currentPhone)
            }
        }
    }

    private var configurationCard: some View {
        GroupBox(label: Label("取号配置", systemImage: "slider.horizontal.3")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("短信签名")
                            .font(.headline)
                        Text("豪猪 `getPhone` 接口本身不支持按短信签名取号；这个字段保留给后续注册流程做短信来源校验，不影响现在接码。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    TextField("例如：花园城停车", text: smsSignatureBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 280)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("运营商")
                            .font(.subheadline.weight(.semibold))
                        Picker("运营商", selection: $selectedCarrier) {
                            ForEach(carrierOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("省份")
                            .font(.subheadline.weight(.semibold))
                        Picker("省份", selection: $selectedProvince) {
                            ForEach(provinceOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("号码类型")
                            .font(.subheadline.weight(.semibold))
                        Picker("号码类型", selection: $selectedCardType) {
                            ForEach(cardTypeOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("首城注册")
                            .font(.subheadline.weight(.semibold))
                        Picker("首城注册", selection: $selectedSeedCity) {
                            ForEach(seedCityOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("扩展城市")
                            .font(.subheadline.weight(.semibold))
                        Picker("扩展城市", selection: $selectedExpansionCity) {
                            ForEach(expansionCityOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    Button(isGettingPhone ? "取号中..." : "开始获取号码") {
                        Task {
                            await getPhone()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canGetPhone || isGettingPhone)

                    Button(isPollingCode ? "轮询中..." : "重新获取验证码") {
                        startMessagePollingTask(maxAttempts: 24)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canGetMessage || isPollingCode)

                    Button(isReleasingPhone ? "释放中..." : "释放当前号码") {
                        Task {
                            await releaseCurrentPhone()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canManageCurrentPhone || isReleasingPhone || isBlacklistingPhone)

                    Button(isBlacklistingPhone ? "拉黑中..." : "拉黑当前号码") {
                        Task {
                            await blacklistCurrentPhone()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canManageCurrentPhone || isReleasingPhone || isBlacklistingPhone)

                    Button(isRegisteringSeedCity ? "注册中..." : "开始首城注册") {
                        Task {
                            try? await startSeedCityRegistration()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canStartSeedRegistration)

                    Button(isRunningExpansionTask ? "执行中..." : "执行扩展城市任务") {
                        Task {
                            await startExpansionTask()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canStartExpansionTask)

                    Button(isLoadingBonusHistory ? "查询中..." : "查询积分历史") {
                        Task {
                            await loadBonusHistory()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canLoadBonusHistory)

                    Spacer()

                    Text("先取号，再点首城注册。首城注册会先发短信，再自动轮询豪猪验证码。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var workflowCard: some View {
        GroupBox(label: Label("流程概览", systemImage: "list.number")) {
            VStack(spacing: 12) {
                ForEach(Array(workflowSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Label(step.title, systemImage: step.systemImage)
                                .font(.headline)
                            Text(step.detail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var zhanjiangPasswordCard: some View {
        GroupBox(label: Label("最后一站：湛江改密码", systemImage: "lock.rotation")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("接码手机号")
                            .font(.subheadline.weight(.semibold))
                        TextField("默认复用当前号码，也可手动改成指定号码", text: $zhanjiangTargetPhone)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("图形验证码")
                            .font(.subheadline.weight(.semibold))
                        TextField("手动输入图中验证码", text: $zhanjiangGraphicCodeInput)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Button(isLoadingZhanjiangGraphic ? "获取中..." : "获取图形验证码") {
                                Task {
                                    await loadZhanjiangGraphicCaptcha()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canLoadZhanjiangGraphic)

                            Button(isSendingZhanjiangSMS ? "发送中..." : "发送改密短信验证码") {
                                Task {
                                    await sendZhanjiangSMSCode()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canSendZhanjiangSMS)

                            Button(isUpdatingZhanjiangPassword ? "提交中..." : "提交修改密码") {
                                Task {
                                    await updateZhanjiangPassword()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canUpdateZhanjiangPassword)
                        }

                        Text("这里会先取图形验证码，再由你手动输入图形码后发短信。短信会复用豪猪当前号码做第二次接码。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Keyword：\(zhanjiangGraphicKeyword.isEmpty ? "待获取" : zhanjiangGraphicKeyword)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("固定密码：\(zhanjiangFixedPassword)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("图形验证码预览")
                            .font(.subheadline.weight(.semibold))

                        if let preview = zhanjiangGraphicPreview {
                            Image(nsImage: preview)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 120, height: 60)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else if isLoadingZhanjiangGraphic {
                            ProgressView()
                                .frame(width: 120, height: 60)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Text(zhanjiangGraphicImageURL.isEmpty ? "尚未获取图形验证码" : "图像加载失败")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 120, height: 60)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
        }
        .task(id: currentPhone) {
            if zhanjiangTargetPhone.isEmpty || zhanjiangTargetPhone == "待获取" {
                zhanjiangTargetPhone = currentPhone == "待获取" ? "" : currentPhone
            }
        }
    }

    private var resultCard: some View {
        GroupBox(label: Label("执行结果预览", systemImage: "person.text.rectangle")) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    betaResultPanel(title: "接码结果", lines: [
                        "手机号：\(currentPhone)",
                        "验证码：\(currentCode)",
                        currentPhoneMeta,
                        currentSMS
                    ])

                    betaResultPanel(title: "首城注册", lines: [
                        "注册城市：\(selectedSeedCity)",
                        "随机姓名：\(seedCityUserName)",
                        "Token：\(seedCityToken)",
                        "UID：\(seedCityUID)",
                        "首城积分：\(seedCityBonus)"
                    ])

                    betaResultPanel(title: "扩展任务", lines: [
                        "目标城市：\(selectedExpansionCity)",
                        "邮箱：\(expansionTaskEmail)",
                        "地址：\(expansionTaskAddress)",
                        "资料状态：\(expansionTaskStatus)",
                        "结果摘要：\(expansionTaskBonus)"
                    ])
                }

                bonusHistoryPanel
                zhanjiangResultPanel
            }
        }
    }

    private var zhanjiangResultPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("湛江改密码准备态")
                .font(.headline)

            HStack(spacing: 14) {
                betaResultPanel(title: "图形验证码", lines: [
                    "目标号码：\(zhanjiangTargetPhone.isEmpty ? "待指定" : zhanjiangTargetPhone)",
                    "图像地址：\(zhanjiangGraphicImageURL.isEmpty ? "待获取" : zhanjiangGraphicImageURL)",
                    "Keyword：\(zhanjiangGraphicKeyword.isEmpty ? "待获取" : zhanjiangGraphicKeyword)",
                    "人工输入：\(zhanjiangGraphicCodeInput.isEmpty ? "待输入" : zhanjiangGraphicCodeInput)"
                ])

                betaResultPanel(title: "改密短信接码", lines: [
                    "短信状态：\(zhanjiangSMSStatus)",
                    "二次验证码：\(zhanjiangReceivedCode)",
                    zhanjiangReceivedSMS,
                    "当前复用号码：\(currentPhone)"
                ])

                betaResultPanel(title: "最终改密提交", lines: [
                    "固定密码：\(zhanjiangFixedPassword)",
                    "提交状态：\(zhanjiangPasswordStatus)",
                    "图形码：\(zhanjiangGraphicCodeInput.isEmpty ? "待输入" : zhanjiangGraphicCodeInput)",
                    "短信码：\(zhanjiangReceivedCode)"
                ])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bonusHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("积分历史")
                    .font(.headline)
                Spacer()
                Text("总积分：\(bonusHistoryTotal)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if bonusHistoryItems.isEmpty {
                Text("暂无历史记录。拿到首城 token 后可直接查询最近 10 条积分流水。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(bonusHistoryItems) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.bizAccountDisplay)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.Remark)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(item.TransTime)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("+\(item.pointsText)")
                                    .font(.system(.body, design: .monospaced))
                                Text("余额 \(item.remainPointsText)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var phonePoolCard: some View {
        GroupBox(label: Label("接码号码池", systemImage: "simcard.2")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button("全选可操作号码") {
                        selectedPhoneIDs = Set(phoneRecords.filter(\.canManage).map(\.id))
                    }
                    .buttonStyle(.bordered)
                    .disabled(phoneRecords.filter(\.canManage).isEmpty)

                    Button("清空选择") {
                        selectedPhoneIDs.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedPhoneIDs.isEmpty)

                    Button("批量释放") {
                        Task {
                            await releaseSelectedPhones()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasSelectedPhones || isReleasingPhone || isBlacklistingPhone)

                    Button("批量拉黑") {
                        Task {
                            await blacklistSelectedPhones()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasSelectedPhones || isReleasingPhone || isBlacklistingPhone)

                    Spacer()

                    Text("可选中多个号码，执行单独或批量释放/拉黑。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if phoneRecords.isEmpty {
                    Text("暂无接码号码。获取号码后会在这里累计展示。")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(phoneRecords) { record in
                            phoneRecordRow(record)
                        }
                    }
                }
            }
        }
    }

    private var logCard: some View {
        GroupBox(label: Label("任务日志", systemImage: "text.append")) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(runtimeLogs.reversed()) { log in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(log.level.color.opacity(0.8))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.timestampText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(log.message)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(log.level == .error ? .red : .secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @MainActor
    private func appendRuntimeLog(message: String, level: BetaStatusTone) {
        guard !message.isEmpty else { return }
        if runtimeLogs.last?.message == message {
            return
        }
        let entry = BetaRuntimeLog(level: level, message: message)
        runtimeLogs.append(entry)
        if runtimeLogs.count > 200 {
            runtimeLogs.removeFirst(runtimeLogs.count - 200)
        }
        print("[Beta][\(entry.level.label)][\(entry.timestampText)] \(entry.message)")
    }

    private func networkDebugLog(prefix: String, detail: String) {
        print("[Beta][\(prefix)] \(detail)")
    }

    private func betaMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func betaResultPanel(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: statusTone.systemImage)
                .foregroundColor(statusTone.color)
            Text(statusMessage)
                .font(.subheadline)
            Spacer()
        }
        .padding(12)
        .background(statusTone.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func phoneRecordRow(_ record: BetaPhoneRecord) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { selectedPhoneIDs.contains(record.id) },
                    set: { isSelected in
                        if isSelected {
                            selectedPhoneIDs.insert(record.id)
                        } else {
                            selectedPhoneIDs.remove(record.id)
                        }
                    }
                )
            )
            .labelsHidden()
            .disabled(!record.canManage)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.phone)
                    .font(.system(.body, design: .monospaced))
                Text("\(record.meta) | 状态：\(record.statusText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !record.codeText.isEmpty {
                    Text("验证码：\(record.codeText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("释放") {
                Task {
                    await releasePhone(record.phone)
                }
            }
            .buttonStyle(.bordered)
            .disabled(!record.canManage || isReleasingPhone || isBlacklistingPhone)

            Button("拉黑") {
                Task {
                    await blacklistPhone(record.phone)
                }
            }
            .buttonStyle(.bordered)
            .disabled(!record.canManage || isReleasingPhone || isBlacklistingPhone)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func loginToHaozhu() async {
        guard hasLoginConfig else { return }
        await MainActor.run {
            isLoggingIn = true
            statusMessage = "正在请求豪猪登录接口..."
            statusTone = .info
        }

        do {
            let response: HaozhuLoginResponse = try await request(
                api: "login",
                queryItems: [
                    URLQueryItem(name: "user", value: dataManager.settings.betaHaozhuAPIUser),
                    URLQueryItem(name: "pass", value: dataManager.settings.betaHaozhuAPIPassword)
                ]
            )

            guard response.isSuccess, let token = response.token, !token.isEmpty else {
                throw HaozhuError.message(response.msg?.isEmpty == false ? response.msg! : "豪猪登录失败")
            }

            await MainActor.run {
                dataManager.settings.betaHaozhuToken = token
                dataManager.saveSettings()
                statusMessage = "登录成功，token 已保存。"
                statusTone = .success
            }

            await refreshSummary()
        } catch {
            await MainActor.run {
                statusMessage = "登录失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }

        await MainActor.run {
            isLoggingIn = false
        }
    }

    @MainActor
    private func logoutHaozhu() {
        dataManager.settings.betaHaozhuToken = ""
        dataManager.saveSettings()
        accountBalance = "--"
        maxAreaCount = "--"
        seedCityToken = "待获取"
        seedCityUID = "待获取"
        seedCityBonus = "待确认"
        seedCityUserName = "待生成"
        seedCityProjectType = "待获取"
        expansionTaskStatus = "未执行"
        expansionTaskBonus = "待统计"
        expansionTaskEmail = "待生成"
        expansionTaskAddress = "待生成"
        phoneRecords.removeAll()
        selectedPhoneIDs.removeAll()
        resetCurrentPhoneState()
        statusMessage = "已退出豪猪登录。"
        statusTone = .info
    }

    private func refreshSummary() async {
        guard hasToken else { return }
        await MainActor.run {
            isRefreshingSummary = true
            statusMessage = "正在刷新账号信息..."
            statusTone = .info
        }

        do {
            let response: HaozhuSummaryResponse = try await request(
                api: "getSummary",
                queryItems: [
                    URLQueryItem(name: "token", value: dataManager.settings.betaHaozhuToken)
                ]
            )

            guard response.isSuccess else {
                throw HaozhuError.message(response.msg?.isEmpty == false ? response.msg! : "账号信息刷新失败")
            }

            await MainActor.run {
                accountBalance = response.money ?? "--"
                maxAreaCount = response.num ?? "--"
                statusMessage = "账号信息已刷新，余额 \(accountBalance)，最大区号数 \(maxAreaCount)。"
                statusTone = .success
            }
        } catch {
            await MainActor.run {
                statusMessage = "刷新账号信息失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }

        await MainActor.run {
            isRefreshingSummary = false
        }
    }

    private func startSeedCityRegistration() async throws {
        guard canStartSeedRegistration else { return }
        let phone = currentPhone
        let userName = randomChineseName()

        await MainActor.run {
            isRegisteringSeedCity = true
            seedCityUserName = userName
            seedCityToken = "注册中..."
            seedCityUID = "注册中..."
            seedCityBonus = "注册中..."
            seedCityProjectType = "注册中..."
            statusMessage = "深圳招商蛇口注册开始，当前号码 \(phone)。"
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isRegisteringSeedCity = false
            }
        }

        do {
            let sendCodeBody = ShenzhenGetCodeBody(
                MallID: shenzhenMallID,
                Mobile: phone,
                SMSType: 1,
                Scene: 1,
                GraphicType: 2,
                Keyword: nil,
                GraphicVCode: nil,
                Header: .init(Token: nil, systemInfo: .default)
            )
            let sendCodeResponse: CMSKCommonResponse<Int> = try await cmskRequest(
                path: "/api/user/User/GetCode",
                body: sendCodeBody
            )
            guard sendCodeResponse.m == 1 else {
                throw HaozhuError.message("深圳发送验证码失败")
            }

            let verificationCode: String
            if selectedMode == .simple && isOneClickUsingSelfPhone {
                await MainActor.run {
                    statusMessage = "深圳短信已发出，请查看自己手机并手动输入验证码。"
                    statusTone = .info
                }
                verificationCode = try await waitForManualSMSCode(
                    stage: .seedRegister(phoneNumber: phone)
                )
            } else {
                await MainActor.run {
                    statusMessage = "深圳短信已发出，开始等待豪猪返回验证码..."
                    statusTone = .info
                }
                await pollMessage(maxAttempts: 24)

                guard let resolvedCode = await MainActor.run(body: { currentVerificationCode }) else {
                    throw HaozhuError.message("深圳验证码未收到或未识别，无法继续注册")
                }
                verificationCode = resolvedCode
            }

            let loginBody = ShenzhenLoginBody(
                MallID: shenzhenMallID,
                InternationalMobileCode: "86",
                Mobile: phone,
                WeChatOpenID: shenzhenWechatOpenID,
                WeChatMiniProgramOpenID: shenzhenMiniOpenID,
                WeChatMiniProgramUnionID: shenzhenMiniUnionID,
                AppID: "",
                Code: "",
                EncryptedData: "",
                Iv: "",
                VCode: verificationCode,
                SMSType: 1,
                Keyword: nil,
                Scene: 1,
                GraphicType: 2,
                GraphicVCode: nil,
                BusinessSourceID: shenzhenBusinessSourceID,
                BusinessSourceData: shenzhenBusinessSourceData,
                LightUID: shenzhenLightUID,
                Header: .init(Token: nil, systemInfo: .default)
            )
            let loginResponse: CMSKCommonResponse<ShenzhenLoginResponseData> = try await cmskRequest(
                path: "/a/liteapp/api/identitys/LoginV3",
                body: loginBody
            )
            guard loginResponse.m == 1, let loginData = loginResponse.d else {
                throw HaozhuError.message("深圳注册登录失败")
            }

            let fullToken = "\(loginData.Token),\(loginData.ProjectType)"
            let mcSettingString = shenzhenMCSetting(userName: userName)
            let mallCardBody = ShenzhenMallCardBody(
                MallID: shenzhenMallID,
                Mobile: phone,
                mcSetting: mcSettingString,
                Header: .init(Token: fullToken, systemInfo: .default)
            )
            let checkResponse: CMSKCommonResponse<Int> = try await cmskRequest(
                path: "/api/user/user/CheckMallCard",
                body: mallCardBody
            )
            guard checkResponse.m == 1 else {
                throw HaozhuError.message("深圳资料校验失败")
            }

            let openCardBody = ShenzhenOpenOrBindCardBody(
                MallID: shenzhenMallID,
                Mobile: phone,
                mcSetting: mcSettingString,
                SNSType: 3,
                RefID: "",
                DataSource: 11,
                InvitedUID: nil,
                UnionID: shenzhenMiniUnionID,
                BusinessSourceID: shenzhenBusinessSourceID,
                BusinessSourceData: shenzhenBusinessSourceData,
                OauthID: shenzhenWechatOpenID,
                MiniOpenID: shenzhenMiniOpenID,
                Header: .init(Token: fullToken, systemInfo: .default)
            )
            let openCardResponse: CMSKCommonResponse<ShenzhenOpenCardResponseData> = try await cmskRequest(
                path: "/api/user/user/OpenOrBindCard",
                body: openCardBody
            )
            guard openCardResponse.m == 1, let openData = openCardResponse.d else {
                throw HaozhuError.message("深圳开卡失败")
            }

            let confirmedBonus = (try? await APIService.shared.getBonus(token: fullToken, mallID: String(shenzhenMallID)))
                ?? Int(openData.Bonus)

            await MainActor.run {
                seedCityToken = fullToken
                seedCityUID = String(loginData.UID)
                seedCityProjectType = String(loginData.ProjectType)
                seedCityBonus = "\(confirmedBonus)"
                statusMessage = "深圳招商蛇口注册完成，账号 \(phone) 已拿到 \(confirmedBonus) 积分。"
                statusTone = .success
            }

        } catch {
            await MainActor.run {
                seedCityToken = "注册失败"
                seedCityUID = "注册失败"
                seedCityBonus = "注册失败"
                seedCityProjectType = "注册失败"
                statusMessage = "深圳招商蛇口注册失败：\(error.localizedDescription)"
                statusTone = .error
            }
            throw error
        }
    }

    private func startExpansionTask() async {
        guard canStartExpansionTask else { return }
        let token = seedCityToken
        let phone = currentPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let userName = seedCityUserName == "待生成" ? randomChineseName() : seedCityUserName

        await MainActor.run {
            isRunningExpansionTask = true
            expansionTaskStatus = "执行中"
            expansionTaskBonus = "统计中"
            statusMessage = "\(selectedExpansionCity) 资料任务开始执行。"
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isRunningExpansionTask = false
            }
        }

        do {
            guard !phone.isEmpty, phone != "待获取" else {
                throw HaozhuError.message("当前手机号为空，无法继续批量开卡")
            }

            var workingToken = token
            let confirmedBonus: String?

            switch selectedExpansionCity {
            case "全部可提交商场":
                let summary = try await runBatchMallSubmission(token: workingToken, phone: phone, userName: userName)
                workingToken = summary.latestToken
                confirmedBonus = summary.resultText

            case "深圳海上世界":
                let email = randomEmail()
                let address = randomAddress()
                await MainActor.run {
                    expansionTaskEmail = email
                    expansionTaskAddress = address
                }
                let mcSetting = shenzhenHaiShangWorldMCSetting(
                    userName: userName,
                    email: email,
                    address: address
                )
                let setting = try? await loadMallCardSetting(mallID: shenzhenHaiShangWorldMallID, token: workingToken)
                workingToken = try await submitMallProfileAndOpenCardIfNeeded(
                    mallID: shenzhenHaiShangWorldMallID,
                    phone: phone,
                    token: workingToken,
                    mcSetting: mcSetting,
                    setting: setting
                )
                confirmedBonus = (try? await APIService.shared.getBonus(token: workingToken, mallID: String(shenzhenHaiShangWorldMallID)))
                    .map(String.init)

            case "赣州招商":
                await MainActor.run {
                    expansionTaskEmail = "不适用"
                    expansionTaskAddress = "不适用"
                }
                let mcSetting = ganzhouMcSetting(userName: userName)
                let setting = try? await loadMallCardSetting(mallID: ganzhouMallID, token: workingToken)
                workingToken = try await submitMallProfileAndOpenCardIfNeeded(
                    mallID: ganzhouMallID,
                    phone: phone,
                    token: workingToken,
                    mcSetting: mcSetting,
                    setting: setting
                )
                confirmedBonus = (try? await APIService.shared.getBonus(token: workingToken, mallID: String(ganzhouMallID)))
                    .map(String.init)

            case "三亚崖州":
                await MainActor.run {
                    expansionTaskEmail = "不适用"
                    expansionTaskAddress = "不适用"
                }

                // 用户提供的访问即赠分接口还不完全确定，这里先做一次宽松尝试，不阻断后续资料提交。
                let templateBody = SanyaTemplatesBody(
                    mallId: sanyaYazhouMallID,
                    appId: "wx0ecc3f8bfd59a0d5",
                    source: 2,
                    moduleLabel: "member",
                    nodeLabels: ["userCenter_bonusDetail", "userCenter_memberUpgrade"],
                    Header: .init(Token: token, systemInfo: .default)
                )
                let templateResponse: CMSKCommonResponse<[SanyaTemplateNode]>? = try? await cmskRequest(
                    path: "/api/msg2/sub/getTemplates",
                    body: templateBody
                )
                let templateSucceeded = templateResponse?.m == 1

                let mcSetting = sanyaYazhouMcSetting()
                let setting = try? await loadMallCardSetting(mallID: sanyaYazhouMallID, token: workingToken)
                workingToken = try await submitMallProfileAndOpenCardIfNeeded(
                    mallID: sanyaYazhouMallID,
                    phone: phone,
                    token: workingToken,
                    mcSetting: mcSetting,
                    setting: setting
                )
                confirmedBonus = (try? await APIService.shared.getBonus(token: workingToken, mallID: String(sanyaYazhouMallID)))
                    .map(String.init)
                await MainActor.run {
                    expansionTaskStatus = templateSucceeded ? "访问+资料已提交" : "资料已提交，访问待复核"
                }

            default:
                throw HaozhuError.message("暂未接入该扩展城市")
            }

            await MainActor.run {
                seedCityToken = workingToken
                if expansionTaskStatus == "执行中" {
                    expansionTaskStatus = "资料已提交"
                }
                expansionTaskBonus = confirmedBonus ?? "已提交，待确认"
                statusMessage = "\(selectedExpansionCity) 资料任务完成。"
                statusTone = .success
            }
        } catch {
            await MainActor.run {
                expansionTaskStatus = "执行失败"
                expansionTaskBonus = "执行失败"
                statusMessage = "\(selectedExpansionCity) 资料任务失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }
    }

    private func runBatchMallSubmission(token: String, phone: String, userName: String) async throws -> BatchMallSubmissionSummary {
        let email = randomEmail()
        let address = randomAddress()
        var submitted: [String] = []
        let skipped: [String] = []
        var failed: [String] = []
        let orderedTargets = orderedBatchMallTargets
        var currentToken = token

        await MainActor.run {
            expansionTaskEmail = email
            expansionTaskAddress = address
            expansionTaskStatus = "批量执行中"
            expansionTaskBonus = "批量准备中"
        }

        for (index, target) in orderedTargets.enumerated() {
            await MainActor.run {
                statusMessage = "批量提交 \(index + 1)/\(orderedTargets.count)：\(target.name)"
                statusTone = .info
                expansionTaskStatus = "批量执行中（\(index + 1)/\(orderedTargets.count)）"
                expansionTaskBonus = "成功 \(submitted.count) · 跳过 \(skipped.count) · 失败 \(failed.count)"
            }

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
                    phone: phone,
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
            await MainActor.run {
                statusMessage = "高优商场补提：\(target.name)"
                statusTone = .info
                expansionTaskStatus = "批量补提中（\(target.name)）"
                expansionTaskBonus = "成功 \(submitted.count) · 跳过 \(skipped.count) · 失败 \(failed.count)"
            }

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
                    phone: phone,
                    token: currentToken,
                    mcSetting: mcSetting,
                    setting: setting
                )
            } catch {
                failed.append("\(target.name) 补提：\(error.localizedDescription)")
            }
        }

        let summary = BatchMallSubmissionSummary(
            submitted: submitted,
            skipped: skipped,
            failed: failed,
            latestToken: currentToken
        )

        guard !summary.submitted.isEmpty else {
            if let firstFailure = summary.failed.first {
                throw HaozhuError.message("批量提交未成功：\(firstFailure)")
            }
            throw HaozhuError.message("当前没有可提交的商场")
        }

        await MainActor.run {
            expansionTaskStatus = summary.statusText
            expansionTaskBonus = summary.resultText
        }

        return summary
    }

    private func submitMallProfileAndOpenCardIfNeeded(
        mallID: Int,
        phone: String,
        token: String,
        mcSetting: String,
        setting: BatchMallCardSetting?
    ) async throws -> String {
        let body = ExpansionPostUserBody(
            MallID: mallID,
            MallCardID: 0,
            mcSetting: mcSetting,
            OauthID: "",
            DataSource: 3,
            Header: .init(Token: token, systemInfo: .default)
        )
        let response: CMSKCommonResponse<Int> = try await cmskRequest(
            path: "/api/user/user/PostUser",
            body: body
        )
        guard response.m == 1 else {
            throw HaozhuError.message(response.e ?? "资料提交失败")
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
        setting: BatchMallCardSetting?
    ) async throws -> String {
        guard let setting else {
            return token
        }

        guard setting.IsOpenCard || setting.IsBindCard else {
            return token
        }

        let checkBody = ShenzhenMallCardBody(
            MallID: mallID,
            Mobile: phone,
            mcSetting: mcSetting,
            Header: .init(Token: token, systemInfo: .default)
        )
        let checkResponse: CMSKCommonResponse<Int> = try await cmskRequest(
            path: "/api/user/user/CheckMallCard",
            body: checkBody
        )
        guard checkResponse.m == 1 else {
            throw HaozhuError.message(checkResponse.e ?? "开卡资料校验失败")
        }

        let openCardBody = ShenzhenOpenOrBindCardBody(
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
        let openCardResponse: CMSKCommonResponse<ShenzhenOpenCardResponseData> = try await cmskRequest(
            path: "/api/user/user/OpenOrBindCard",
            body: openCardBody
        )

        if openCardResponse.m == 307 {
            return token
        }

        guard openCardResponse.m == 1, let openData = openCardResponse.d else {
            throw HaozhuError.message(openCardResponse.e ?? "开卡失败")
        }

        return "\(openData.Token),\(openData.ProjectType)"
    }

    private var orderedBatchMallTargets: [BatchMallSubmissionTarget] {
        return allMallBatchTargets.sorted { lhs, rhs in
            let leftIndex = preferredScoreMallIDs.firstIndex(of: lhs.mallID) ?? Int.max
            let rightIndex = preferredScoreMallIDs.firstIndex(of: rhs.mallID) ?? Int.max
            if leftIndex == rightIndex {
                return lhs.mallID < rhs.mallID
            }
            return leftIndex < rightIndex
        }
    }

    private var preferredScoreMallTargets: [BatchMallSubmissionTarget] {
        preferredScoreMallIDs.compactMap { preferredMallID in
            allMallBatchTargets.first { $0.mallID == preferredMallID }
        }
    }

    private func loadMallCardSetting(mallID: Int, token: String) async throws -> BatchMallCardSetting {
        let body = BatchMallCardSettingBody(
            MallID: mallID,
            Header: .init(Token: token, systemInfo: .default)
        )
        let response: CMSKCommonResponse<BatchMallCardSetting> = try await cmskRequest(
            path: "/api/user/MallCardSetting/GetForOpenCard",
            body: body
        )
        guard response.m == 1, let setting = response.d else {
            throw HaozhuError.message(response.e ?? "商场配置获取失败")
        }
        return setting
    }

    private func batchMCSetting(
        for target: BatchMallSubmissionTarget,
        setting: BatchMallCardSetting?,
        userName: String,
        email: String,
        address: String
    ) -> String {
        switch target.mallID {
        case shenzhenHaiShangWorldMallID:
            return shenzhenHaiShangWorldMCSetting(
                userName: userName,
                email: email,
                address: address
            )
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
        for target: BatchMallSubmissionTarget,
        setting: BatchMallCardSetting?,
        userName: String,
        email: String,
        address: String
    ) -> String {
        genericMallMCSetting(
            fieldNames: mergedMallFieldNames(
                from: setting,
                includeDefaultCompletionFields: true
            ),
            userName: userName,
            email: email,
            address: address,
            overrides: preferredMallPayloadOverrides(for: target)
        )
    }

    private func mergedMallFieldNames(
        from setting: BatchMallCardSetting?,
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

    private func preferredMallPayloadOverrides(for target: BatchMallSubmissionTarget) -> [String: String] {
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

    private func loadBonusHistory() async {
        guard canLoadBonusHistory else { return }
        let token = seedCityToken

        await MainActor.run {
            isLoadingBonusHistory = true
            statusMessage = "正在查询当前账号积分历史..."
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isLoadingBonusHistory = false
            }
        }

        do {
            let body = BonusHistoryRequestBody(
                MallID: bonusHistoryMallID,
                PageIndex: 1,
                PageSize: 10,
                Header: .init(Token: token, systemInfo: .default)
            )
            let response: CMSKCommonResponse<BonusHistoryResponseData> = try await cmskRequest(
                path: "/api/user/Bonus/ZsskGetHuiDouList",
                body: body
            )
            guard response.m == 1, let history = response.d else {
                throw HaozhuError.message("积分历史查询失败")
            }

            await MainActor.run {
                bonusHistoryTotal = history.TotalBonusStr ?? history.totalBonusText
                bonusHistoryItems = history.List
                statusMessage = "积分历史已刷新，当前累计 \(bonusHistoryTotal)。"
                statusTone = .success
            }
        } catch {
            await MainActor.run {
                bonusHistoryTotal = "查询失败"
                bonusHistoryItems = []
                statusMessage = "积分历史查询失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }
    }

    private func loadZhanjiangGraphicCaptcha() async {
        guard canLoadZhanjiangGraphic else { return }
        let token = seedCityToken

        await MainActor.run {
            isLoadingZhanjiangGraphic = true
            zhanjiangSMSStatus = "图形验证码获取中"
            statusMessage = "正在请求湛江改密码图形验证码..."
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isLoadingZhanjiangGraphic = false
            }
        }

        do {
            let body = ZhanjiangGraphicCaptchaBody(
                MallID: zhanjiangMallID,
                Width: 60,
                Height: 30,
                Scene: 2,
                Type: 2,
                Header: .init(Token: token, systemInfo: .default)
            )
            let response: CMSKCommonResponse<ZhanjiangGraphicCaptchaData> = try await cmskRequest(
                path: "/api/user/GraphicVcode/Get",
                body: body
            )
            guard response.m == 1, let data = response.d else {
                throw HaozhuError.message("图形验证码获取失败")
            }

            let preview = try await loadGraphicCaptchaPreview(from: data.Image)

            await MainActor.run {
                zhanjiangGraphicImageURL = data.Image
                zhanjiangGraphicPreview = preview
                zhanjiangGraphicKeyword = data.Keyword
                zhanjiangGraphicCodeInput = ""
                zhanjiangSMSStatus = "图形验证码已就绪"
                statusMessage = "图形验证码已获取，请手动输入后发送改密短信验证码。"
                statusTone = .success
            }
        } catch {
            await MainActor.run {
                zhanjiangGraphicPreview = nil
                zhanjiangSMSStatus = "图形验证码获取失败"
                statusMessage = "图形验证码获取失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }
    }

    private func sendZhanjiangSMSCode() async {
        guard canSendZhanjiangSMS else { return }
        let token = seedCityToken
        let phone = zhanjiangTargetPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let graphicCode = zhanjiangGraphicCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousCodes = Set([currentVerificationCode, zhanjiangVerificationCode].compactMap { $0 })
        let previousMessages = Set([
            normalizedSMSContent(currentSMS),
            normalizedSMSContent(zhanjiangReceivedSMS)
        ].compactMap { $0 })

        await MainActor.run {
            isSendingZhanjiangSMS = true
            zhanjiangSMSStatus = "短信验证码发送中"
            zhanjiangReceivedCode = "待获取"
            zhanjiangReceivedSMS = "短信内容：等待接收"
            zhanjiangSMSFailureReason = ""
            statusMessage = "正在发送湛江改密码短信验证码..."
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isSendingZhanjiangSMS = false
            }
        }

        do {
            if !(selectedMode == .simple && isOneClickUsingSelfPhone) {
                let specifiedPhoneResponse: HaozhuPhoneResponse = try await request(
                    api: "getPhone",
                    queryItems: [
                        URLQueryItem(name: "token", value: dataManager.settings.betaHaozhuToken),
                        URLQueryItem(name: "sid", value: dataManager.settings.betaHaozhuProjectID),
                        URLQueryItem(name: "phone", value: phone)
                    ]
                )
                guard specifiedPhoneResponse.isSuccess else {
                    throw HaozhuError.message(specifiedPhoneResponse.msg ?? "指定号码接管失败")
                }
            }

            let body = ZhanjiangSMSCodeBody(
                Mobile: phone,
                MallID: zhanjiangMallID,
                SMSType: 4,
                Scene: 2,
                GraphicType: 2,
                Keyword: zhanjiangGraphicKeyword,
                GraphicVCode: graphicCode,
                Header: .init(Token: token, systemInfo: .default)
            )
            let response: CMSKCommonResponse<Int> = try await cmskRequest(
                path: "/api/user/user/getcode",
                body: body
            )
            guard response.m == 1 else {
                throw HaozhuError.message(response.e ?? "改密短信验证码发送失败")
            }

            if selectedMode == .simple && isOneClickUsingSelfPhone {
                await MainActor.run {
                    currentPhone = phone
                    zhanjiangSMSStatus = "短信已发送，等待手动输入"
                    statusMessage = "改密短信验证码已发送，请查看自己手机并手动输入。"
                    statusTone = .success
                }
                _ = try await waitForManualSMSCode(
                    stage: .zhanjiangPassword(phoneNumber: phone)
                )
            } else {
                await MainActor.run {
                    currentPhone = phone
                    zhanjiangSMSStatus = "短信已发送，等待豪猪二次接码"
                    statusMessage = "改密短信验证码已发送，开始对号码 \(phone) 进行二次接码。"
                    statusTone = .success
                }

                await pollZhanjiangMessage(
                    phone: phone,
                    maxAttempts: 24,
                    previousCodes: previousCodes,
                    previousMessages: previousMessages
                )
            }
        } catch {
            await MainActor.run {
                zhanjiangSMSStatus = "短信发送失败"
                zhanjiangSMSFailureReason = error.localizedDescription
                statusMessage = "发送湛江改密短信验证码失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }
    }

    private func pollZhanjiangMessage(phone: String, maxAttempts: Int, previousCodes: Set<String>, previousMessages: Set<String>) async {
        await MainActor.run {
            isPollingCode = true
            shouldStopPolling = false
            zhanjiangReceivedCode = "轮询中..."
            zhanjiangReceivedSMS = "短信内容：等待接收"
            zhanjiangSMSStatus = "二次接码中"
        }

        defer {
            Task { @MainActor in
                isPollingCode = false
            }
        }

        for attempt in 1...maxAttempts {
            if Task.isCancelled {
                await markZhanjiangPollingCancelled(for: phone)
                return
            }

            let shouldAbort = await MainActor.run { shouldStopPolling || currentPhone != phone }
            if shouldAbort {
                await MainActor.run {
                    zhanjiangReceivedCode = "已停止"
                    zhanjiangReceivedSMS = "短信内容：轮询已停止"
                    zhanjiangSMSStatus = "轮询已停止"
                    statusMessage = "湛江改密短信轮询已停止。"
                    statusTone = .info
                }
                return
            }

            do {
                let response: HaozhuMessageResponse = try await request(
                    api: "getMessage",
                    queryItems: [
                        URLQueryItem(name: "token", value: dataManager.settings.betaHaozhuToken),
                        URLQueryItem(name: "sid", value: dataManager.settings.betaHaozhuProjectID),
                        URLQueryItem(name: "phone", value: phone)
                    ]
                )

                if response.isSuccess, let sms = response.sms, !sms.isEmpty {
                    let code = extractVerificationCode(from: response.yzm, fallback: sms)
                    let normalizedSMS = normalizedSMSContent(sms)
                    let isSameSMS = normalizedSMS.map { previousMessages.contains($0) } ?? false
                    let isSameCode = code.map { previousCodes.contains($0) } ?? false
                    if isSameSMS || isSameCode {
                        await MainActor.run {
                            zhanjiangSMSStatus = "检测到旧短信，继续等待新验证码"
                            statusMessage = "湛江改密仍在等待新的短信验证码，已跳过旧短信。"
                            statusTone = .info
                        }
                        if attempt < maxAttempts {
                            do {
                                try await cancellableSleep(nanoseconds: pollingSleepNanoseconds(for: attempt))
                            } catch is CancellationError {
                                await markZhanjiangPollingCancelled(for: phone)
                                return
                            } catch {
                                return
                            }
                        }
                        continue
                    }

                    await MainActor.run {
                        zhanjiangReceivedSMS = "短信内容：\(sms)"
                        zhanjiangReceivedCode = code ?? "未识别"
                        zhanjiangSMSStatus = "已收到改密短信验证码"
                        statusMessage = "湛江改密短信验证码已获取：\(zhanjiangReceivedCode)"
                        statusTone = .success
                    }
                    return
                }

                await MainActor.run {
                    zhanjiangSMSStatus = "第 \(attempt)/\(maxAttempts) 次轮询中"
                    statusMessage = "湛江改密短信第 \(attempt)/\(maxAttempts) 次轮询中..."
                    statusTone = .info
                }
            } catch is CancellationError {
                await markZhanjiangPollingCancelled(for: phone)
                return
            } catch {
                await MainActor.run {
                    zhanjiangSMSStatus = "轮询异常"
                    statusMessage = "湛江改密短信轮询异常：\(error.localizedDescription)"
                    statusTone = .error
                }
            }

            if attempt < maxAttempts {
                do {
                    try await cancellableSleep(nanoseconds: pollingSleepNanoseconds(for: attempt))
                } catch is CancellationError {
                    await markZhanjiangPollingCancelled(for: phone)
                    return
                } catch {
                    return
                }
            }
        }

        await MainActor.run {
            zhanjiangReceivedCode = "超时未收到"
            zhanjiangReceivedSMS = "短信内容：120 秒内未收到可识别短信"
            zhanjiangSMSStatus = "轮询超时"
            statusMessage = "湛江改密短信验证码轮询超时。"
            statusTone = .error
        }
    }

    private func updateZhanjiangPassword() async {
        guard canUpdateZhanjiangPassword else { return }
        guard let smsCode = zhanjiangVerificationCode else {
            await MainActor.run {
                statusMessage = "提交改密码前必须先拿到可用短信验证码。"
                statusTone = .error
            }
            return
        }
        let token = seedCityToken
        let phone = zhanjiangTargetPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let graphicCode = zhanjiangGraphicCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run {
            isUpdatingZhanjiangPassword = true
            zhanjiangPasswordStatus = "提交中"
            statusMessage = "正在提交湛江改密码请求..."
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isUpdatingZhanjiangPassword = false
            }
        }

        do {
            let body = ZhanjiangUpdatePasswordBody(
                MallID: zhanjiangMallID,
                Pwd: zhanjiangFixedPassword,
                Mobile: phone,
                VCode: smsCode,
                SMSType: 4,
                Keyword: zhanjiangGraphicKeyword,
                Scene: 2,
                GraphicType: 2,
                GraphicVCode: graphicCode,
                Header: .init(Token: token, systemInfo: .default)
            )
            let response: CMSKCommonResponse<Int> = try await cmskRequest(
                path: "/api/user/user/UpdateUserPwd",
                body: body
            )
            guard response.m == 1 else {
                throw HaozhuError.message("改密码失败")
            }

            await MainActor.run {
                zhanjiangPasswordStatus = "修改成功"
                statusMessage = "湛江站改密码已完成，固定密码为 \(zhanjiangFixedPassword)。"
                statusTone = .success
            }
        } catch {
            await MainActor.run {
                zhanjiangPasswordStatus = "修改失败"
                statusMessage = "湛江站改密码失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }
    }

    @MainActor
    private func startOneClickFlowTask() {
        oneClickFlowTask?.cancel()
        oneClickFlowTask = Task {
            await runOneClickFlow()
            await MainActor.run {
                oneClickFlowTask = nil
            }
        }
    }

    @MainActor
    private func startMessagePollingTask(maxAttempts: Int) {
        messagePollingTask?.cancel()
        messagePollingTask = Task {
            await pollMessage(maxAttempts: maxAttempts)
            await MainActor.run {
                messagePollingTask = nil
            }
        }
    }

    @MainActor
    private func cancelLongRunningTasks() {
        shouldStopPolling = true
        messagePollingTask?.cancel()
        messagePollingTask = nil
        oneClickFlowTask?.cancel()
        oneClickFlowTask = nil
    }

    private func cancellableSleep(nanoseconds: UInt64) async throws {
        try Task.checkCancellation()
        try await Task.sleep(nanoseconds: nanoseconds)
        try Task.checkCancellation()
    }

    private func pollingSleepNanoseconds(for attempt: Int) -> UInt64 {
        let extraSeconds = min((attempt - 1) / 8, 2)
        return UInt64(5 + extraSeconds) * 1_000_000_000
    }

    @MainActor
    private func waitForSheetDismissal(_ isPresented: @escaping () -> Bool) async throws {
        while isPresented() {
            try await cancellableSleep(nanoseconds: 200_000_000)
        }
    }

    private func markSMSPollingCancelled(phone: String) async {
        await MainActor.run {
            currentCode = "已停止"
            currentSMS = "短信内容：轮询任务已取消"
            updatePhoneRecord(
                phone: phone,
                status: .stopped,
                code: "已停止",
                sms: "轮询任务已取消"
            )
            statusMessage = "号码 \(phone) 的验证码轮询已取消。"
            statusTone = .info
        }
    }

    private func markZhanjiangPollingCancelled(for phone: String) async {
        await MainActor.run {
            zhanjiangReceivedCode = "已停止"
            zhanjiangReceivedSMS = "短信内容：轮询任务已取消"
            zhanjiangSMSStatus = "轮询已取消"
            statusMessage = "号码 \(phone) 的湛江改密短信轮询已取消。"
            statusTone = .info
        }
    }

    private func runOneClickFlow() async {
        guard !isRunningOneClick else { return }

        await MainActor.run {
            resetOneClickWorkingState()
            isRunningOneClick = true
            statusMessage = "一键流程启动，正在准备执行环境..."
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isRunningOneClick = false
            }
        }

        do {
            let usingSelfPhone = await MainActor.run { isOneClickUsingSelfPhone }

            try await runOneClickStep(.prepare) {
                if usingSelfPhone {
                    try await prepareSelfManagedPhoneForOneClick()
                } else {
                    try await ensureOneClickLogin()
                }
            }

            try await runOneClickStep(.getPhone) {
                if usingSelfPhone {
                    await MainActor.run {
                        applySelfManagedPhoneToCurrentState()
                    }
                } else {
                    try await getPhoneWithRetry(maxAttempts: 10)
                }
            }

            try await runOneClickStep(.seedRegister) {
                try await startSeedCityRegistration()
                let hasUsableToken = await MainActor.run { hasUsableSeedCityToken }
                if !hasUsableToken {
                    throw HaozhuError.message("首城注册后未拿到可用 token")
                }
            }

            try await runOneClickStep(.allMallSubmit) {
                await MainActor.run {
                    selectedExpansionCity = "全部可提交商场"
                }
                await startExpansionTask()
                let failed = await MainActor.run { expansionTaskStatus.contains("执行失败") }
                if failed {
                    throw HaozhuError.message("批量商场提交失败")
                }
            }

            try await runOneClickStep(.bonusHistory) {
                await loadBonusHistoryWithoutBlocking()
            }

            try await runOneClickStep(.graphicCaptcha) {
                await loadZhanjiangGraphicCaptcha()
                let hasGraphicKeyword = await MainActor.run { !zhanjiangGraphicKeyword.isEmpty }
                if !hasGraphicKeyword {
                    throw HaozhuError.message("图形验证码未获取成功")
                }
                await MainActor.run {
                    showingCaptchaSheet = true
                }
                try await waitForSheetDismissal { showingCaptchaSheet }
            }

            try await runOneClickStep(.passwordSMS) {
                try await sendZhanjiangSMSCodeWithRetry(maxAttempts: 3)
            }

            try await runOneClickStep(.passwordUpdate) {
                await updateZhanjiangPassword()
                let passwordUpdated = await MainActor.run { zhanjiangPasswordStatus == "修改成功" }
                if !passwordUpdated {
                    throw HaozhuError.message("湛江改密码未成功")
                }
            }

            let bonusText = await MainActor.run {
                resolvedBonusHistoryText
            }
            let detail = await MainActor.run {
                isOneClickUsingSelfPhone
                    ? "自有手机号流程完成，UID：\(seedCityUID)"
                    : "首城+全商场提交流程完成，UID：\(seedCityUID)"
            }
            let result = OneClickAccountResult(
                phone: currentPhone,
                password: zhanjiangFixedPassword,
                bonusText: bonusText,
                detail: detail,
                token: seedCityToken,
                uid: seedCityUID
            )
            let completedPhone = currentPhone

            await MainActor.run {
                oneClickResults.removeAll { $0.phone == result.phone }
                oneClickResults.insert(result, at: 0)
                statusMessage = autoAddOneClickAccounts
                    ? "一键流程已完成，账号 \(currentPhone) 正在自动加入主程序号码池。"
                    : "一键流程已完成，账号 \(currentPhone) 可直接加入主程序号码池。"
                statusTone = .success
            }

            if autoAddOneClickAccounts {
                await addOneClickResultToPool(result.id)
            }

            let cleanupSucceeded = await finalizeOneClickPhoneAfterCompletion(completedPhone)

            await MainActor.run {
                resetOneClickWorkingState()
                if usingSelfPhone {
                    statusMessage = "上一轮账号已完成并归档，自有手机号流程已结束，现在可以直接继续下一轮。"
                } else {
                    statusMessage = cleanupSucceeded
                        ? "上一轮账号已完成并归档，号码已自动拉黑，现在可以继续获取下一个账号。"
                        : "上一轮账号已完成并归档，但号码自动拉黑失败，请检查后再继续。"
                }
                statusTone = .success
            }
        } catch is CancellationError {
            await MainActor.run {
                showingCaptchaSheet = false
                showingManualSMSCodeSheet = false
                statusMessage = "一键流程已取消。"
                statusTone = .info
            }
        } catch {
            await MainActor.run {
                statusMessage = "一键流程中断：\(error.localizedDescription)"
                statusTone = .error
            }
        }
    }

    private func ensureOneClickLogin() async throws {
        try await runOneClickStep(.prepare) {
            let loggedInBeforeRefresh = await MainActor.run { hasToken }
            if !loggedInBeforeRefresh {
                await loginToHaozhu()
            }
            let loggedInAfterRefresh = await MainActor.run { hasToken }
            if !loggedInAfterRefresh {
                throw HaozhuError.message("豪猪登录失败")
            }
            await refreshSummary()
        }
    }

    private func getPhoneWithRetry(maxAttempts: Int) async throws {
        var lastErrorMessage = "取号后未拿到有效手机号"

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            await MainActor.run {
                statusMessage = "正在取号，第 \(attempt)/\(maxAttempts) 次尝试..."
                statusTone = .info
            }

            await getPhone()

            if await MainActor.run(body: { hasCurrentPhone }) {
                await MainActor.run {
                    zhanjiangTargetPhone = currentPhone
                    statusMessage = "取号成功，已在第 \(attempt)/\(maxAttempts) 次尝试拿到号码 \(currentPhone)。"
                    statusTone = .success
                }
                return
            }

            lastErrorMessage = await MainActor.run {
                if statusMessage.hasPrefix("取号失败：") {
                    return statusMessage.replacingOccurrences(of: "取号失败：", with: "")
                }
                return "取号后未拿到有效手机号"
            }

            if attempt < maxAttempts {
                await MainActor.run {
                    statusMessage = "第 \(attempt)/\(maxAttempts) 次取号失败，2 秒后自动重试..."
                    statusTone = .info
                }
                try await cancellableSleep(nanoseconds: 2_000_000_000)
            }
        }

        throw HaozhuError.message("连续 \(maxAttempts) 次取号失败：\(lastErrorMessage)")
    }

    private func finalizeOneClickPhoneAfterCompletion(_ phone: String) async -> Bool {
        guard !isOneClickUsingSelfPhone else { return true }
        guard !phone.isEmpty, phone != "待获取" else { return false }

        await MainActor.run {
            statusMessage = "一键流程收尾：正在自动拉黑本轮号码 \(phone)..."
            statusTone = .info
        }

        await blacklistPhone(phone)

        return await MainActor.run {
            phoneRecords.first(where: { $0.phone == phone })?.status == .blacklisted
        }
    }

    private func sendZhanjiangSMSCodeWithRetry(maxAttempts: Int) async throws {
        var lastErrorMessage = "湛江改密短信验证码未收到"

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            await MainActor.run {
                statusMessage = "正在发送湛江改密短信验证码，第 \(attempt)/\(maxAttempts) 次尝试..."
                statusTone = .info
            }

            await sendZhanjiangSMSCode()

            if await MainActor.run(body: { zhanjiangVerificationCode != nil }) {
                return
            }

            let failureReason = await MainActor.run {
                if !zhanjiangSMSFailureReason.isEmpty {
                    return zhanjiangSMSFailureReason
                }
                if statusMessage.hasPrefix("发送湛江改密短信验证码失败：") {
                    return statusMessage.replacingOccurrences(of: "发送湛江改密短信验证码失败：", with: "")
                }
                return "湛江改密短信验证码未收到"
            }
            lastErrorMessage = failureReason

            let shouldRetryGraphicCaptcha = failureReason.contains("图形验证码错误")
            guard attempt < maxAttempts else { break }

            if shouldRetryGraphicCaptcha {
                await MainActor.run {
                    statusMessage = "图形验证码错误，正在重新获取图形验证码，请重新输入。"
                    statusTone = .info
                }
                await loadZhanjiangGraphicCaptcha()
                let loaded = await MainActor.run { !zhanjiangGraphicKeyword.isEmpty }
                guard loaded else {
                    throw HaozhuError.message("图形验证码重新获取失败")
                }
                await MainActor.run {
                    showingCaptchaSheet = true
                }
                try await waitForSheetDismissal { showingCaptchaSheet }
                continue
            }

            throw HaozhuError.message(failureReason)
        }

        throw HaozhuError.message(lastErrorMessage)
    }

    private func runExpansionCityWithVerification(city: String, expectedMinimumIncrease: Int?, maxAttempts: Int) async throws {
        var baseline = await refreshBonusHistoryAndGetTotal()
        var lastErrorMessage = "\(city) 执行后未确认到积分变化"

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            await MainActor.run {
                selectedExpansionCity = city
                statusMessage = "\(city) 第 \(attempt)/\(maxAttempts) 次执行前，等待系统稳定..."
                statusTone = .info
            }
            try await cancellableSleep(nanoseconds: 3_000_000_000)

            await startExpansionTask()

            let taskFailed = await MainActor.run { expansionTaskStatus.contains("失败") }
            if taskFailed {
                lastErrorMessage = await MainActor.run { expansionTaskStatus }
            }

            await MainActor.run {
                statusMessage = "\(city) 已提交，等待积分系统反应..."
                statusTone = .info
            }
            try await cancellableSleep(nanoseconds: 5_000_000_000)

            let latestTotal = await refreshBonusHistoryAndGetTotal()

            if let expectedMinimumIncrease {
                if latestTotal >= baseline + expectedMinimumIncrease {
                    await MainActor.run {
                        statusMessage = "\(city) 已确认到账，积分增量 \(latestTotal - baseline)。"
                        statusTone = .success
                    }
                    return
                }
                lastErrorMessage = "\(city) 第 \(attempt)/\(maxAttempts) 次执行后积分仅从 \(baseline) 到 \(latestTotal)，未达到预期增量 \(expectedMinimumIncrease)"
            } else if !taskFailed {
                await MainActor.run {
                    statusMessage = "\(city) 已执行并完成一次积分复核。"
                    statusTone = .success
                }
                return
            }

            if attempt < maxAttempts {
                await MainActor.run {
                    statusMessage = "\(city) 第 \(attempt)/\(maxAttempts) 次结果未达预期，准备稍后补试一次..."
                    statusTone = .info
                }
                try await cancellableSleep(nanoseconds: 5_000_000_000)
                baseline = latestTotal
            }
        }

        throw HaozhuError.message(lastErrorMessage)
    }

    private func refreshBonusHistoryAndGetTotal() async -> Int {
        await loadBonusHistory()
        return await MainActor.run {
            parsedBonusHistoryTotal
        }
    }

    private func loadBonusHistoryWithoutBlocking() async {
        await loadBonusHistory()
        let queryFailed = await MainActor.run { bonusHistoryTotal == "查询失败" }
        if queryFailed {
            await MainActor.run {
                statusMessage = "积分历史暂未查到，本轮继续执行后续步骤。"
                statusTone = .info
            }
        }
    }

    @MainActor
    private var parsedBonusHistoryTotal: Int {
        let sanitized = bonusHistoryTotal
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(sanitized) {
            return value
        }
        if let doubleValue = Double(sanitized) {
            return Int(doubleValue)
        }
        return bonusHistoryItems.first.map { Int($0.RemainPoints) } ?? 0
    }

    @MainActor
    private var resolvedBonusHistoryText: String {
        bonusHistoryTotal == "查询失败" ? "待查询" : bonusHistoryTotal
    }

    private func runOneClickStep(_ step: OneClickFlowStep, action: @escaping @Sendable () async throws -> Void) async throws {
        await MainActor.run {
            oneClickStepStates[step] = .running
            statusMessage = "正在执行：\(step.title(for: selectedOneClickPhoneSource))"
            statusTone = .info
        }

        do {
            try Task.checkCancellation()
            try await action()
            try Task.checkCancellation()
            await MainActor.run {
                oneClickStepStates[step] = .success
            }
        } catch is CancellationError {
            await MainActor.run {
                oneClickStepStates[step] = .failed("已取消")
            }
            throw CancellationError()
        } catch {
            await MainActor.run {
                oneClickStepStates[step] = .failed(error.localizedDescription)
            }
            throw error
        }
    }

    @MainActor
    private func resetOneClickStepStates() {
        oneClickStepStates = OneClickFlowStep.defaultStates
    }

    @MainActor
    private func resetOneClickWorkingState() {
        resetCurrentPhoneState()
        resetOneClickStepStates()
        selectedSeedCity = "深圳招商蛇口"
        selectedExpansionCity = "全部可提交商场"
        seedCityToken = "待获取"
        seedCityUID = "待获取"
        seedCityBonus = "待确认"
        seedCityUserName = "待生成"
        seedCityProjectType = "待获取"
        expansionTaskStatus = "未执行"
        expansionTaskBonus = "待统计"
        expansionTaskEmail = "待生成"
        expansionTaskAddress = "待生成"
        bonusHistoryTotal = "待查询"
        bonusHistoryItems = []
        zhanjiangGraphicImageURL = ""
        zhanjiangGraphicPreview = nil
        zhanjiangGraphicKeyword = ""
        zhanjiangGraphicCodeInput = ""
        zhanjiangTargetPhone = ""
        zhanjiangSMSStatus = "未开始"
        zhanjiangReceivedCode = "待获取"
        zhanjiangReceivedSMS = "短信内容：待返回"
        zhanjiangSMSFailureReason = ""
        zhanjiangPasswordStatus = "未提交"
        showingCaptchaSheet = false
        showingManualSMSCodeSheet = false
        manualSMSCodeInput = ""
        shouldStopPolling = false
    }

    private func addOneClickResultToPool(_ id: UUID) async {
        guard let index = oneClickResults.firstIndex(where: { $0.id == id }) else { return }
        let result = oneClickResults[index]
        if accountManager.isPhoneNumberExists(result.phone) {
            await MainActor.run {
                oneClickResults[index].addedToPool = true
            }
            accountManager.showToast("手机号 \(result.phone) 已存在，已跳过重复添加。", type: .info)
            return
        }

        let success = await accountManager.addAccountWithValidation(username: result.phone, password: result.password)
        if success {
            await MainActor.run {
                oneClickResults[index].addedToPool = true
                oneClickResults[index].status = .added
            }
        }
    }

    private func addAllOneClickResultsToPool() async {
        for result in oneClickResults where !result.addedToPool {
            await addOneClickResultToPool(result.id)
        }
    }

    private func loadOneClickResults() {
        guard let data = UserDefaults.standard.data(forKey: oneClickResultsStorageKey) else { return }
        guard let results = try? JSONDecoder().decode([OneClickAccountResult].self, from: data) else { return }
        oneClickResults = results
    }

    private func saveOneClickResults() {
        guard let data = try? JSONEncoder().encode(oneClickResults) else { return }
        UserDefaults.standard.set(data, forKey: oneClickResultsStorageKey)
    }

    private func loadGraphicCaptchaPreview(from rawURL: String) async throws -> NSImage {
        let normalizedRawURL = normalizedGraphicImageURL(rawURL)
        let candidates = [normalizedRawURL, rawURL]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                continue
            }
            if let image = NSImage(data: data) {
                return image
            }
        }

        throw HaozhuError.message("图形验证码图片下载失败")
    }

    private func normalizedGraphicImageURL(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        if raw.hasPrefix("http://") {
            return "https://" + raw.dropFirst("http://".count)
        }
        return raw
    }

    private func normalizedSMSContent(_ value: String) -> String? {
        let raw = value
            .replacingOccurrences(of: "短信内容：", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              raw != "待返回",
              raw != "等待接收",
              raw != "轮询已停止",
              raw != "120 秒内未收到可识别短信" else {
            return nil
        }
        return raw
    }

    private func getPhone() async {
        guard canGetPhone else { return }
        await MainActor.run {
            isGettingPhone = true
            shouldStopPolling = false
            statusMessage = "正在请求豪猪取号接口..."
            statusTone = .info
        }

        do {
            var queryItems = [
                URLQueryItem(name: "token", value: dataManager.settings.betaHaozhuToken),
                URLQueryItem(name: "sid", value: dataManager.settings.betaHaozhuProjectID)
            ]

            if let carrierCode = carrierCode(for: selectedCarrier) {
                queryItems.append(URLQueryItem(name: "isp", value: carrierCode))
            }
            if let provinceCode = provinceCode(for: selectedProvince) {
                queryItems.append(URLQueryItem(name: "Province", value: provinceCode))
            }
            if let cardTypeCode = cardTypeCode(for: selectedCardType) {
                queryItems.append(URLQueryItem(name: "ascription", value: cardTypeCode))
            }

            let response: HaozhuPhoneResponse = try await request(
                api: "getPhone",
                queryItems: queryItems
            )

            guard response.isSuccess, let phone = response.phone, !phone.isEmpty else {
                throw HaozhuError.message(response.msg ?? "豪猪取号失败")
            }

            await MainActor.run {
                currentPhone = phone
                let carrier = response.sp ?? "未知运营商"
                let location = response.phoneGSD ?? "未知归属地"
                currentPhoneMeta = "运营商/归属地：\(carrier) / \(location)"
                currentCode = "待获取"
                currentSMS = "短信内容：待返回"
                shouldStopPolling = false
                upsertPhoneRecord(
                    phone: phone,
                    meta: "\(carrier) / \(location)",
                    status: .ready,
                    code: nil,
                    sms: nil
                )
                statusMessage = "取号成功：\(phone)，现在可以直接点首城注册。"
                statusTone = .success
            }

            await MainActor.run {
                isGettingPhone = false
            }
        } catch {
            await MainActor.run {
                statusMessage = "取号失败：\(error.localizedDescription)"
                statusTone = .error
                isGettingPhone = false
            }
        }
    }

    private func pollMessage(maxAttempts: Int) async {
        guard canGetMessage else { return }
        let pollingPhone = currentPhone
        await MainActor.run {
            isPollingCode = true
            shouldStopPolling = false
            currentCode = "轮询中..."
            currentSMS = "短信内容：等待接收"
            statusMessage = "号码 \(pollingPhone) 正在轮询验证码，最多尝试 \(maxAttempts) 轮..."
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isPollingCode = false
            }
        }

        for attempt in 1...maxAttempts {
            if Task.isCancelled {
                await markSMSPollingCancelled(phone: pollingPhone)
                return
            }

            let shouldAbort = await MainActor.run { shouldStopPolling || currentPhone != pollingPhone }
            if shouldAbort {
                await MainActor.run {
                    currentCode = "已停止"
                    currentSMS = "短信内容：当前号码轮询已被释放或拉黑操作接管"
                    updatePhoneRecord(
                        phone: pollingPhone,
                        status: .stopped,
                        code: "已停止",
                        sms: "当前号码轮询已被释放或拉黑操作接管"
                    )
                    statusMessage = "号码 \(pollingPhone) 的验证码轮询已停止。"
                    statusTone = .info
                }
                return
            }

            do {
                let response: HaozhuMessageResponse = try await request(
                    api: "getMessage",
                    queryItems: [
                        URLQueryItem(name: "token", value: dataManager.settings.betaHaozhuToken),
                        URLQueryItem(name: "sid", value: dataManager.settings.betaHaozhuProjectID),
                        URLQueryItem(name: "phone", value: pollingPhone)
                    ]
                )

                if response.isSuccess, let sms = response.sms, !sms.isEmpty {
                    await MainActor.run {
                        currentSMS = "短信内容：\(sms)"
                        currentCode = extractVerificationCode(from: response.yzm, fallback: sms) ?? "未识别"
                        updatePhoneRecord(
                            phone: pollingPhone,
                            status: .receivedCode,
                            code: currentCode,
                            sms: sms
                        )
                        statusMessage = "号码 \(pollingPhone) 验证码已获取：\(currentCode)"
                        statusTone = .success
                    }
                    return
                }

                await MainActor.run {
                    updatePhoneRecord(phone: pollingPhone, status: .polling, code: "轮询中", sms: nil)
                    statusMessage = "号码 \(pollingPhone) 第 \(attempt)/\(maxAttempts) 次轮询中，暂未收到短信..."
                    statusTone = .info
                }
            } catch is CancellationError {
                await markSMSPollingCancelled(phone: pollingPhone)
                return
            } catch {
                await MainActor.run {
                    statusMessage = "号码 \(pollingPhone) 第 \(attempt)/\(maxAttempts) 次轮询异常：\(error.localizedDescription)"
                    statusTone = .error
                }
            }

            if attempt < maxAttempts {
                do {
                    try await cancellableSleep(nanoseconds: pollingSleepNanoseconds(for: attempt))
                } catch is CancellationError {
                    await markSMSPollingCancelled(phone: pollingPhone)
                    return
                } catch {
                    return
                }
            }
        }

        await MainActor.run {
            currentCode = "超时未收到"
            currentSMS = "短信内容：\(maxAttempts) 轮内未收到可识别短信"
            updatePhoneRecord(
                phone: pollingPhone,
                status: .timeout,
                code: "超时未收到",
                sms: "\(maxAttempts) 轮内未收到可识别短信"
            )
            statusMessage = "号码 \(pollingPhone) 验证码轮询超时，请稍后重试、释放号码或重新取号。"
            statusTone = .error
        }
    }

    private func releaseCurrentPhone() async {
        guard canManageCurrentPhone else { return }
        await releasePhone(currentPhone)
    }

    private func blacklistCurrentPhone() async {
        guard canManageCurrentPhone else { return }
        await blacklistPhone(currentPhone)
    }

    private func releaseSelectedPhones() async {
        let phones = selectedManageablePhones.map(\.phone)
        for phone in phones {
            await releasePhone(phone)
        }
    }

    private func blacklistSelectedPhones() async {
        let phones = selectedManageablePhones.map(\.phone)
        for phone in phones {
            await blacklistPhone(phone)
        }
    }

    private func releasePhone(_ phone: String) async {
        guard !phone.isEmpty, phone != "待获取" else { return }
        await MainActor.run {
            isReleasingPhone = true
            if currentPhone == phone {
                shouldStopPolling = true
                messagePollingTask?.cancel()
            }
            updatePhoneRecord(phone: phone, status: .releasing, code: nil, sms: nil)
            statusMessage = "正在释放号码 \(phone)..."
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isReleasingPhone = false
            }
        }

        do {
            let response: HaozhuActionResponse = try await request(
                api: "cancelRecv",
                queryItems: [
                    URLQueryItem(name: "token", value: dataManager.settings.betaHaozhuToken),
                    URLQueryItem(name: "sid", value: dataManager.settings.betaHaozhuProjectID),
                    URLQueryItem(name: "phone", value: phone)
                ]
            )

            guard response.isSuccess else {
                throw HaozhuError.message(response.msg ?? "释放号码失败")
            }

            await MainActor.run {
                updatePhoneRecord(phone: phone, status: .released, code: nil, sms: nil)
                selectedPhoneIDs.remove(phone)
                statusMessage = "号码已释放：\(phone)"
                statusTone = .success
                if currentPhone == phone {
                    resetCurrentPhoneState()
                }
            }
        } catch {
            await MainActor.run {
                if currentPhone == phone {
                    shouldStopPolling = false
                }
                updatePhoneRecord(phone: phone, status: .actionFailed, code: nil, sms: error.localizedDescription)
                statusMessage = "释放号码失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }
    }

    private func blacklistPhone(_ phone: String) async {
        guard !phone.isEmpty, phone != "待获取" else { return }
        await MainActor.run {
            isBlacklistingPhone = true
            if currentPhone == phone {
                shouldStopPolling = true
                messagePollingTask?.cancel()
            }
            updatePhoneRecord(phone: phone, status: .blacklisting, code: nil, sms: nil)
            statusMessage = "正在拉黑号码 \(phone)..."
            statusTone = .info
        }

        defer {
            Task { @MainActor in
                isBlacklistingPhone = false
            }
        }

        do {
            let response: HaozhuActionResponse = try await request(
                api: "addBlacklist",
                queryItems: [
                    URLQueryItem(name: "token", value: dataManager.settings.betaHaozhuToken),
                    URLQueryItem(name: "sid", value: dataManager.settings.betaHaozhuProjectID),
                    URLQueryItem(name: "phone", value: phone)
                ]
            )

            guard response.isSuccess else {
                throw HaozhuError.message(response.msg ?? "拉黑号码失败")
            }

            await MainActor.run {
                updatePhoneRecord(phone: phone, status: .blacklisted, code: nil, sms: nil)
                selectedPhoneIDs.remove(phone)
                statusMessage = "号码已拉黑：\(phone)"
                statusTone = .success
                if currentPhone == phone {
                    resetCurrentPhoneState()
                }
            }
        } catch {
            await MainActor.run {
                if currentPhone == phone {
                    shouldStopPolling = false
                }
                updatePhoneRecord(phone: phone, status: .actionFailed, code: nil, sms: error.localizedDescription)
                statusMessage = "拉黑号码失败：\(error.localizedDescription)"
                statusTone = .error
            }
        }
    }

    @MainActor
    private func resetCurrentPhoneState() {
        shouldStopPolling = false
        messagePollingTask?.cancel()
        messagePollingTask = nil
        currentPhone = "待获取"
        currentPhoneMeta = "运营商/归属地：待返回"
        currentCode = "待获取"
        currentSMS = "短信内容：待返回"
    }

    @MainActor
    private func upsertPhoneRecord(phone: String, meta: String, status: BetaPhoneStatus, code: String?, sms: String?) {
        if let index = phoneRecords.firstIndex(where: { $0.phone == phone }) {
            phoneRecords[index].meta = meta
            phoneRecords[index].status = status
            if let code {
                phoneRecords[index].codeText = code
            }
            if let sms {
                phoneRecords[index].smsText = sms
            }
        } else {
            phoneRecords.insert(
                BetaPhoneRecord(
                    id: phone,
                    phone: phone,
                    meta: meta,
                    status: status,
                    codeText: code ?? "",
                    smsText: sms ?? ""
                ),
                at: 0
            )
        }
    }

    @MainActor
    private func updatePhoneRecord(phone: String, status: BetaPhoneStatus, code: String?, sms: String?) {
        guard let index = phoneRecords.firstIndex(where: { $0.phone == phone }) else { return }
        phoneRecords[index].status = status
        if let code {
            phoneRecords[index].codeText = code
        }
        if let sms {
            phoneRecords[index].smsText = sms
        }
    }

    private func carrierCode(for option: String) -> String? {
        switch option {
        case "中国移动": return "1"
        case "中国联通": return "2"
        case "中国电信": return "3"
        default: return nil
        }
    }

    private func provinceCode(for option: String) -> String? {
        switch option {
        case "广东": return "44"
        case "江苏": return "32"
        case "上海": return "31"
        case "浙江": return "33"
        default: return nil
        }
    }

    private func cardTypeCode(for option: String) -> String? {
        switch option {
        case "虚拟号": return "1"
        case "实卡": return "2"
        default: return nil
        }
    }

    private func shenzhenMCSetting(userName: String) -> String {
        let payload = [
            "UserName": userName,
            "Gender": shenzhenGender,
            "Birthday": shenzhenBirthday,
            "Remark1": shenzhenRemark1
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return #"{"UserName":"测试员","Gender":"1","Birthday":"1985-01-01","Remark1":"南山蛇口"}"#
        }
        return text
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

    private func extractVerificationCode(from primary: String?, fallback: String?) -> String? {
        let candidates = [primary, fallback]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for candidate in candidates {
            if candidate.allSatisfy(\.isNumber), (4...8).contains(candidate.count) {
                return candidate
            }

            if let match = candidate.range(of: #"\d{4,8}"#, options: .regularExpression) {
                return String(candidate[match])
            }
        }

        return nil
    }

    private func prepareSelfManagedPhoneForOneClick() async throws {
        let phone = normalizedManualOneClickPhone
        guard phone.count == 11 else {
            throw HaozhuError.message("请输入你自己的 11 位手机号")
        }

        await MainActor.run {
            manualOneClickPhone = phone
            statusMessage = "已切换到自有手机号模式，本轮将使用 \(phone) 手动接收短信验证码。"
            statusTone = .success
        }
    }

    @MainActor
    private func applySelfManagedPhoneToCurrentState() {
        let phone = normalizedManualOneClickPhone
        currentPhone = phone
        currentPhoneMeta = "接码方式：自有手机号"
        currentCode = "待手动输入"
        currentSMS = "短信内容：请查看自己手机并手动输入"
        zhanjiangTargetPhone = phone
        statusMessage = "已确认自有手机号 \(phone)，后续验证码改为手动输入。"
        statusTone = .success
    }

    private func waitForManualSMSCode(stage: ManualSMSCodeStage) async throws -> String {
        await MainActor.run {
            manualSMSCodeStage = stage
            manualSMSCodeInput = ""
            showingManualSMSCodeSheet = true
            statusMessage = stage.waitingStatusMessage
            statusTone = .info
        }

        try await waitForSheetDismissal { showingManualSMSCodeSheet }

        let code = await MainActor.run {
            manualSMSCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !code.isEmpty else {
            throw HaozhuError.message(stage.cancelMessage)
        }

        await MainActor.run {
            switch stage.target {
            case .seedRegister:
                currentCode = code
                currentSMS = "短信内容：用户手动输入"
            case .zhanjiangPassword:
                zhanjiangReceivedCode = code
                zhanjiangReceivedSMS = "短信内容：用户手动输入"
                zhanjiangSMSStatus = "已收到改密短信验证码"
            }
            statusMessage = stage.successMessage(code: code)
            statusTone = .success
        }

        return code
    }

    private func shenzhenHaiShangWorldMCSetting(userName: String, email: String, address: String) -> String {
        let payload = [
            "Birthday": shenzhenBirthday,
            "Gender": shenzhenGender,
            "UserName": userName,
            "Email": email,
            "Address": address,
            "HasChildren": "1",
            "ShoppingInterestList": "2,6",
            "HobbyList": "2,6",
            "Conveyance": "0"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return #"{"Birthday":"1985-01-01","Gender":"1","UserName":"测试员","Email":"test@test.com","Address":"深圳市南山区海上世界1号","HasChildren":"1","ShoppingInterestList":"2,6","HobbyList":"2,6","Conveyance":"0"}"#
        }
        return text
    }

    private func ganzhouMcSetting(userName: String) -> String {
        let payload = [
            "UserName": userName,
            "Gender": shenzhenGender,
            "Birthday": shenzhenBirthday,
            "Age": ganzhouFixedAge,
            "HasChildren": "1",
            "IDNum": ganzhouFixedIDNumber,
            "Conveyance": "0",
            "ActiveInterestList": "1,2",
            "ShoppingInterestList": "2,6"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return #"{"UserName":"测试员","Gender":"1","Birthday":"1985-01-01","Age":"41","HasChildren":"1","IDNum":"131121200007099415","Conveyance":"0","ActiveInterestList":"1,2","ShoppingInterestList":"2,6"}"#
        }
        return text
    }

    private func sanyaYazhouMcSetting() -> String {
        let payload = [
            "Gender": shenzhenGender,
            "Birthday": shenzhenBirthday,
            "ProvincialAreas": "{\"ProvinceID\":110000,\"Province\":\"北京市\",\"CityID\":110100,\"City\":\"北京市\",\"DistrictsID\":110101,\"Districts\":\"东城区\"}",
            "Education": "1",
            "Marital": "0",
            "HasChildren": "1",
            "Conveyance": "0"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return #"{"Gender":"1","Birthday":"1985-01-01","ProvincialAreas":"{\"ProvinceID\":110000,\"Province\":\"北京市\",\"CityID\":110100,\"City\":\"北京市\",\"DistrictsID\":110101,\"Districts\":\"东城区\"}","Education":"1","Marital":"0","HasChildren":"1","Conveyance":"0"}"#
        }
        return text
    }

    private func cmskRequest<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        guard let url = URL(string: "https://m-bms.cmsk1979.com\(path)") else {
            throw HaozhuError.message("深圳接口地址错误")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.69(0x1800452e) NetType/WIFI Language/zh_CN",
            forHTTPHeaderField: "User-Agent"
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        if let bodyText = String(data: request.httpBody ?? Data(), encoding: .utf8) {
            networkDebugLog(prefix: "CMSK REQ", detail: "\(path) \(bodyText)")
        } else {
            networkDebugLog(prefix: "CMSK REQ", detail: "\(path) <body decode failed>")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? ""
            networkDebugLog(prefix: "CMSK RESP", detail: "\(path) HTTP \(httpResponse.statusCode) \(raw)")
            throw HaozhuError.message("深圳接口 HTTP \(httpResponse.statusCode)")
        }
        let raw = String(data: data, encoding: .utf8) ?? "无法解析深圳接口响应"
        networkDebugLog(prefix: "CMSK RESP", detail: "\(path) \(raw)")

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HaozhuError.message(raw)
        }
    }

    private func request<T: Decodable>(api: String, queryItems: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(string: normalizedServerURL + "/sms/") else {
            throw HaozhuError.message("服务器地址格式不正确")
        }
        components.queryItems = [URLQueryItem(name: "api", value: api)] + queryItems

        guard let url = components.url else {
            throw HaozhuError.message("接口地址拼接失败")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        networkDebugLog(prefix: "HAOZHU REQ", detail: url.absoluteString)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? ""
            networkDebugLog(prefix: "HAOZHU RESP", detail: "HTTP \(httpResponse.statusCode) \(raw)")
            throw HaozhuError.message("HTTP \(httpResponse.statusCode)")
        }
        let raw = String(data: data, encoding: .utf8) ?? "无法解析响应"
        networkDebugLog(prefix: "HAOZHU RESP", detail: raw)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HaozhuError.message(raw)
        }
    }
}

private struct BetaWorkflowStep {
    let title: String
    let detail: String
    let systemImage: String
}

private struct BetaRuntimeLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let level: BetaStatusTone
    let message: String

    var timestampText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

private struct BetaPhoneRecord: Identifiable {
    let id: String
    let phone: String
    var meta: String
    var status: BetaPhoneStatus
    var codeText: String
    var smsText: String

    var canManage: Bool {
        switch status {
        case .released, .blacklisted, .releasing, .blacklisting:
            return false
        default:
            return true
        }
    }

    var statusText: String {
        status.label
    }
}

private enum BetaPhoneStatus {
    case ready
    case polling
    case receivedCode
    case timeout
    case stopped
    case releasing
    case blacklisting
    case released
    case blacklisted
    case actionFailed

    var label: String {
        switch self {
        case .ready: return "已取号待发码"
        case .polling: return "轮询中"
        case .receivedCode: return "已收到验证码"
        case .timeout: return "轮询超时"
        case .stopped: return "已停止"
        case .releasing: return "释放中"
        case .blacklisting: return "拉黑中"
        case .released: return "已释放"
        case .blacklisted: return "已拉黑"
        case .actionFailed: return "操作失败"
        }
    }
}

private struct CMSKSystemInfo: Codable {
    let model: String
    let SDKVersion: String
    let system: String
    let version: String
    let miniVersion: String

    static let `default` = CMSKSystemInfo(
        model: "iPhone 15 pro max<iPhone16,2>",
        SDKVersion: "3.14.3",
        system: "iOS 18.4",
        version: "8.0.69",
        miniVersion: "1.0.76"
    )
}

private struct CMSKHeader: Codable {
    let Token: String?
    let systemInfo: CMSKSystemInfo
}

private struct CMSKCommonResponse<T: Decodable>: Decodable {
    let m: Int
    let d: T?
    let e: String?
}

private struct ShenzhenGetCodeBody: Codable {
    let MallID: Int
    let Mobile: String
    let SMSType: Int
    let Scene: Int
    let GraphicType: Int
    let Keyword: String?
    let GraphicVCode: String?
    let Header: CMSKHeader
}

private struct ShenzhenLoginBody: Codable {
    let MallID: Int
    let InternationalMobileCode: String
    let Mobile: String
    let WeChatOpenID: String
    let WeChatMiniProgramOpenID: String
    let WeChatMiniProgramUnionID: String
    let AppID: String
    let Code: String
    let EncryptedData: String
    let Iv: String
    let VCode: String
    let SMSType: Int
    let Keyword: String?
    let Scene: Int
    let GraphicType: Int
    let GraphicVCode: String?
    let BusinessSourceID: String
    let BusinessSourceData: String
    let LightUID: String
    let Header: CMSKHeader
}

private struct ShenzhenLoginResponseData: Decodable {
    let MallID: Int
    let Mobile: String
    let ProjectType: Int
    let Token: String
    let UID: Int
    let NickName: String?
    let IsRegister: Bool?
}

private struct ShenzhenMallCardBody: Codable {
    let MallID: Int
    let Mobile: String
    let mcSetting: String
    let Header: CMSKHeader
}

private struct ShenzhenOpenOrBindCardBody: Codable {
    let MallID: Int
    let Mobile: String
    let mcSetting: String
    let SNSType: Int
    let RefID: String
    let DataSource: Int
    let InvitedUID: String?
    let UnionID: String
    let BusinessSourceID: String
    let BusinessSourceData: String
    let OauthID: String
    let MiniOpenID: String
    let Header: CMSKHeader
}

private struct ShenzhenOpenCardResponseData: Decodable {
    let UID: Int
    let MallID: Int
    let Token: String
    let Bonus: Double
    let ProjectType: Int
}

private struct ExpansionPostUserBody: Codable {
    let MallID: Int
    let MallCardID: Int
    let mcSetting: String
    let OauthID: String
    let DataSource: Int
    let Header: CMSKHeader
}

private struct BonusHistoryRequestBody: Codable {
    let MallID: Int
    let PageIndex: Int
    let PageSize: Int
    let Header: CMSKHeader
}

private struct BonusHistoryResponseData: Decodable {
    let TotalBonus: Double?
    let TotalBonusStr: String?
    let List: [BonusHistoryItem]

    var totalBonusText: String {
        if let TotalBonus {
            if TotalBonus.rounded(.towardZero) == TotalBonus {
                return String(Int(TotalBonus))
            }
            return String(TotalBonus)
        }
        return "待查询"
    }
}

private struct BonusHistoryItem: Decodable, Identifiable {
    let TransId: String
    let TransTime: String
    let Points: Double
    let Remark: String
    let RemainPoints: Double
    let BizAccountName: String?

    var id: String { TransId }

    var pointsText: String {
        if Points.rounded(.towardZero) == Points {
            return String(Int(Points))
        }
        return String(Points)
    }

    var remainPointsText: String {
        if RemainPoints.rounded(.towardZero) == RemainPoints {
            return String(Int(RemainPoints))
        }
        return String(RemainPoints)
    }

    var bizAccountDisplay: String {
        let trimmed = BizAccountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "未命名积分记录" : trimmed
    }
}

private struct ZhanjiangGraphicCaptchaBody: Codable {
    let MallID: Int
    let Width: Int
    let Height: Int
    let Scene: Int
    let `Type`: Int
    let Header: CMSKHeader
}

private struct ZhanjiangGraphicCaptchaData: Decodable {
    let Image: String
    let Keyword: String
}

private struct ZhanjiangSMSCodeBody: Codable {
    let Mobile: String
    let MallID: Int
    let SMSType: Int
    let Scene: Int
    let GraphicType: Int
    let Keyword: String
    let GraphicVCode: String
    let Header: CMSKHeader
}

private struct ZhanjiangUpdatePasswordBody: Codable {
    let MallID: Int
    let Pwd: String
    let Mobile: String
    let VCode: String
    let SMSType: Int
    let Keyword: String
    let Scene: Int
    let GraphicType: Int
    let GraphicVCode: String
    let Header: CMSKHeader
}

private struct SanyaTemplatesBody: Codable {
    let mallId: Int
    let appId: String
    let source: Int
    let moduleLabel: String
    let nodeLabels: [String]
    let Header: CMSKHeader
}

private struct SanyaTemplateNode: Decodable {
    let nodeId: Int?
    let moduleId: Int?
}

private struct BatchMallSubmissionTarget {
    let mallID: Int
    let name: String
}

private struct BatchMallSubmissionSummary {
    let submitted: [String]
    let skipped: [String]
    let failed: [String]
    let latestToken: String

    var statusText: String {
        "批量完成：成功 \(submitted.count) 个，跳过 \(skipped.count) 个，失败 \(failed.count) 个"
    }

    var resultText: String {
        let failurePreview = failed.prefix(2).joined(separator: "；")
        if failurePreview.isEmpty {
            return "成功 \(submitted.count) · 跳过 \(skipped.count) · 失败 0"
        }
        return "成功 \(submitted.count) · 跳过 \(skipped.count) · 失败 \(failed.count)：\(failurePreview)"
    }
}

private struct BatchMallCardSettingBody: Codable {
    let MallID: Int
    let Header: CMSKHeader
}

private struct BatchMallCardSetting: Decodable {
    let IsOpenCard: Bool
    let IsBindCard: Bool
    let RequiredFieldsList: [BatchMallCardField]?
    let ProfileFieldsList: [BatchMallCardField]?
    let MallCardOptionsList: [BatchMallCardField]?
}

private struct BatchMallCardField: Decodable {
    let Name: String
}

private struct HaozhuLoginResponse: Decodable {
    let msg: String?
    let code: String?
    let token: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        code = Self.decodeFlexibleString(container: container, key: .code)
    }

    private enum CodingKeys: String, CodingKey {
        case msg
        case code
        case token
    }

    var isSuccess: Bool {
        code == "0" || code == "200"
    }
}

private struct HaozhuSummaryResponse: Decodable {
    let msg: String?
    let code: String?
    let money: String?
    let num: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        money = try container.decodeIfPresent(String.self, forKey: .money)
        code = Self.decodeFlexibleString(container: container, key: .code)
        num = Self.decodeFlexibleString(container: container, key: .num)
    }

    private enum CodingKeys: String, CodingKey {
        case msg
        case code
        case money
        case num
    }

    var isSuccess: Bool {
        code == "0" || code == "200"
    }
}

private struct HaozhuPhoneResponse: Decodable {
    let msg: String?
    let code: String?
    let phone: String?
    let sp: String?
    let phoneGSD: String?
    let sid: String?
    let shopName: String?
    let countryName: String?

    enum CodingKeys: String, CodingKey {
        case msg
        case code
        case phone
        case sp
        case sid
        case shopName = "shop_name"
        case countryName = "country_name"
        case phoneGSD = "phone_gsd"
    }

    var isSuccess: Bool {
        code == "0" || code == "200"
    }
}

private struct HaozhuMessageResponse: Decodable {
    let msg: String?
    let code: String?
    let sms: String?
    let yzm: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        sms = try container.decodeIfPresent(String.self, forKey: .sms)
        yzm = try container.decodeIfPresent(String.self, forKey: .yzm)
        code = Self.decodeFlexibleString(container: container, key: .code)
    }

    private enum CodingKeys: String, CodingKey {
        case msg
        case code
        case sms
        case yzm
    }

    var isSuccess: Bool {
        code == "0" || code == "200"
    }
}

private struct HaozhuActionResponse: Decodable {
    let msg: String?
    let code: String?
    let data: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        data = Self.decodeFlexibleString(container: container, key: .data)
        code = Self.decodeFlexibleString(container: container, key: .code)
    }

    private enum CodingKeys: String, CodingKey {
        case msg
        case code
        case data
    }

    var isSuccess: Bool {
        code == "0" || code == "200"
    }
}

private extension Decodable {
    static func decodeFlexibleString<K: CodingKey>(container: KeyedDecodingContainer<K>, key: K) -> String? {
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return nil
    }
}

private enum BetaWindowMode: String, CaseIterable {
    case simple = "普通模式"
    case professional = "专业模式"
}

private enum OneClickPhoneSource: String, CaseIterable {
    case haozhu = "豪猪接码"
    case selfManaged = "自有手机号"
}

private enum OneClickFlowStep: Int, CaseIterable, Identifiable {
    case prepare
    case getPhone
    case seedRegister
    case allMallSubmit
    case bonusHistory
    case graphicCaptcha
    case passwordSMS
    case passwordUpdate

    var id: Int { rawValue }

    func title(for phoneSource: OneClickPhoneSource) -> String {
        switch (self, phoneSource) {
        case (.prepare, .haozhu): return "准备豪猪环境"
        case (.prepare, .selfManaged): return "准备执行环境"
        case (.getPhone, .haozhu): return "获取接码号码"
        case (.getPhone, .selfManaged): return "确认自有手机号"
        case (.seedRegister, _): return "首城注册"
        case (.allMallSubmit, _): return "批量刷全部商场"
        case (.bonusHistory, _): return "刷新积分展示"
        case (.graphicCaptcha, _): return "等待图形验证码"
        case (.passwordSMS, .haozhu): return "二次短信接码"
        case (.passwordSMS, .selfManaged): return "手动输入改密短信"
        case (.passwordUpdate, _): return "自动改密完成"
        }
    }

    static var defaultStates: [OneClickFlowStep: OneClickStepState] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, .pending) })
    }
}

private enum OneClickStepState: Equatable {
    case pending
    case running
    case success
    case failed(String)

    var title: String {
        switch self {
        case .pending: return "待执行"
        case .running: return "执行中"
        case .success: return "已完成"
        case .failed: return "失败"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "circle.dashed"
        case .running: return "hourglass"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .running: return .accentColor
        case .success: return .green
        case .failed: return .red
        }
    }

    func detailText(for step: OneClickFlowStep, phoneSource: OneClickPhoneSource) -> String {
        switch self {
        case .pending:
            return "等待执行 \(step.title(for: phoneSource))"
        case .running:
            return "正在自动处理，请稍候"
        case .success:
            return "该节点已自动完成"
        case .failed(let message):
            return message
        }
    }
}

private enum ManualSMSCodeTarget {
    case seedRegister
    case zhanjiangPassword
}

private enum ManualSMSCodeStage {
    case seedRegister(phoneNumber: String)
    case zhanjiangPassword(phoneNumber: String)

    var target: ManualSMSCodeTarget {
        switch self {
        case .seedRegister:
            return .seedRegister
        case .zhanjiangPassword:
            return .zhanjiangPassword
        }
    }

    var title: String {
        switch self {
        case .seedRegister:
            return "输入首城注册验证码"
        case .zhanjiangPassword:
            return "输入湛江改密验证码"
        }
    }

    var prompt: String {
        switch self {
        case .seedRegister:
            return "深圳注册短信已经发出，请查看你自己的手机，把收到的验证码填进来。"
        case .zhanjiangPassword:
            return "湛江改密短信已经发出，请查看你自己的手机，把收到的验证码填进来。"
        }
    }

    var phoneNumber: String {
        switch self {
        case .seedRegister(let phoneNumber), .zhanjiangPassword(let phoneNumber):
            return phoneNumber
        }
    }

    var waitingStatusMessage: String {
        switch self {
        case .seedRegister(let phoneNumber):
            return "深圳短信已发出，等待你手动输入 \(phoneNumber) 的验证码。"
        case .zhanjiangPassword(let phoneNumber):
            return "湛江改密短信已发出，等待你手动输入 \(phoneNumber) 的验证码。"
        }
    }

    var cancelMessage: String {
        switch self {
        case .seedRegister:
            return "你还没有输入深圳注册验证码"
        case .zhanjiangPassword:
            return "你还没有输入湛江改密短信验证码"
        }
    }

    func successMessage(code: String) -> String {
        switch self {
        case .seedRegister:
            return "已手动录入深圳注册验证码：\(code)"
        case .zhanjiangPassword:
            return "已手动录入湛江改密验证码：\(code)"
        }
    }
}

private struct OneClickAccountResult: Identifiable, Codable, Equatable {
    let id: UUID
    let phone: String
    let password: String
    let bonusText: String
    let detail: String
    let token: String
    let uid: String
    var status: OneClickAccountResultStatus = .ready
    var addedToPool = false

    init(
        id: UUID = UUID(),
        phone: String,
        password: String,
        bonusText: String,
        detail: String,
        token: String,
        uid: String,
        status: OneClickAccountResultStatus = .ready,
        addedToPool: Bool = false
    ) {
        self.id = id
        self.phone = phone
        self.password = password
        self.bonusText = bonusText
        self.detail = detail
        self.token = token
        self.uid = uid
        self.status = status
        self.addedToPool = addedToPool
    }
}

private enum OneClickAccountResultStatus: String, Codable, Equatable {
    case ready = "待加入"
    case added = "已加入"

    var icon: String {
        switch self {
        case .ready: return "tray.and.arrow.down"
        case .added: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .ready: return .accentColor
        case .added: return .green
        }
    }
}

private enum BetaStatusTone {
    case success
    case error
    case info

    var label: String {
        switch self {
        case .success: return "SUCCESS"
        case .error: return "ERROR"
        case .info: return "INFO"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
}

private enum HaozhuError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text):
            return text
        }
    }
}
