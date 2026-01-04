// Purpose: In-app log viewer window and LogStore for debugging.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import AppKit

struct LogEntry: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let category: String
    let message: String

    init(category: String, message: String) {
        self.id = UUID()
        self.date = Date()
        self.category = category
        self.message = message
    }
}

@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()
    @Published private(set) var entries: [LogEntry] = []
    private let maxEntries = 3000

    func add(category: String, _ message: String) {
        entries.append(LogEntry(category: category, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}

struct LogsView: View {
    @StateObject private var logStore = LogStore.shared
    @State private var autoScroll = true
    @State private var showTimestamps = true

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func copyAll() {
        let text = logStore.entries.map { entry in
            let prefix: String
            if showTimestamps {
                prefix = "[\(Self.dateFormatter.string(from: entry.date))] [\(entry.category)] "
            } else {
                prefix = "[\(entry.category)] "
            }
            return prefix + entry.message
        }.joined(separator: "\n\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("日志")
                    .font(.headline)
                Spacer()

                Toggle("自动滚动", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("自动滚动")

                Toggle("时间", isOn: $showTimestamps)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("显示时间")

                Button("复制全部") {
                    copyAll()
                }
                .buttonStyle(.bordered)

                Button("清空") {
                    logStore.clear()
                }
                .buttonStyle(.bordered)
            }
            .padding(12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(logStore.entries) { entry in
                            let prefix: String = {
                                if showTimestamps {
                                    return "[\(Self.dateFormatter.string(from: entry.date))] [\(entry.category)] "
                                }
                                return "[\(entry.category)] "
                            }()

                            Text(prefix + entry.message)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: logStore.entries.count) { _, _ in
                    guard autoScroll, let last = logStore.entries.last else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 760, idealWidth: 900, maxWidth: 1200, minHeight: 520, idealHeight: 680, maxHeight: 900)
    }
}
