import Foundation

struct CheckinMallInfo: Identifiable, Hashable {
    let mallID: Int
    let name: String

    var id: Int { mallID }
}

enum CheckinMallCatalog {
    static let all: [CheckinMallInfo] = [
        .init(mallID: 10431, name: "南京招商花园城"),
        .init(mallID: 10724, name: "招商花园城（燕子矶店）"),
        .init(mallID: 11026, name: "深圳招商蛇口"),
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
        .init(mallID: 12654, name: "长沙梅溪湖招商花园城"),
        .init(mallID: 12655, name: "少荃体育中心花园里"),
        .init(mallID: 12792, name: "上海海上世界"),
        .init(mallID: 12795, name: "成都金牛招商花园城"),
        .init(mallID: 12797, name: "南京玄武招商花园城"),
        .init(mallID: 12908, name: "招商绿洲智谷花园里"),
        .init(mallID: 12909, name: "璀璨花园里"),
        .init(mallID: 12994, name: "杭州城北招商花园城")
    ]

    static func name(for mallID: Int) -> String? {
        all.first(where: { $0.mallID == mallID })?.name
    }
}
