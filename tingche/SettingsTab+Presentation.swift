// Purpose: Presentation mapping for SettingsTab (subtitle and icon name).
// Author: Achord <achordchan@gmail.com>
import Foundation

extension SettingsTab {
    var subtitle: String {
        switch self {
        case .basic:
            return "车牌与兑换相关设置"
        case .security:
            return "备份、恢复与数据记录"
        case .advanced:
            return "自动化与调试设置"
        }
    }

    var iconName: String {
        switch self {
        case .basic:
            return "gearshape.fill"
        case .security:
            return "lock.shield.fill"
        case .advanced:
            return "gearshape.2.fill"
        }
    }
}
