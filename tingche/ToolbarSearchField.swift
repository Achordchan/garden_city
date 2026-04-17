import AppKit
import SwiftUI

struct ToolbarSearchField: NSViewRepresentable {
    let query: String
    let shouldFocus: Bool
    let onQueryChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onQueryChange: onQueryChange)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.placeholderString = "搜索账号手机号"
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.delegate = context.coordinator
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.submitSearch(_:))
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        context.coordinator.onQueryChange = onQueryChange

        if nsView.stringValue != query {
            nsView.stringValue = query
        }

        if shouldFocus, !context.coordinator.hasAppliedInitialFocus {
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                window.makeFirstResponder(nsView)
                context.coordinator.hasAppliedInitialFocus = true
            }
        } else if !shouldFocus {
            context.coordinator.hasAppliedInitialFocus = false
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var hasAppliedInitialFocus = false
        var onQueryChange: (String) -> Void
        private var pendingWorkItem: DispatchWorkItem?

        init(onQueryChange: @escaping (String) -> Void) {
            self.onQueryChange = onQueryChange
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            let value = field.stringValue

            pendingWorkItem?.cancel()

            if value.isEmpty {
                onQueryChange("")
                return
            }

            let workItem = DispatchWorkItem { [onQueryChange] in
                onQueryChange(value)
            }
            pendingWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
        }

        @objc func submitSearch(_ sender: NSSearchField) {
            pendingWorkItem?.cancel()
            onQueryChange(sender.stringValue)
        }
    }
}
