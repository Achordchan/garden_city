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
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = false
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        context.coordinator.onQueryChange = onQueryChange

        if nsView.stringValue != query {
            context.coordinator.isProgrammaticUpdate = true
            nsView.stringValue = query
            context.coordinator.isProgrammaticUpdate = false
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
        var isProgrammaticUpdate = false
        private var pendingWorkItem: DispatchWorkItem?
        private var lastSentValue = ""
        private let debounceDelay: TimeInterval = 0.12

        init(onQueryChange: @escaping (String) -> Void) {
            self.onQueryChange = onQueryChange
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            guard !isProgrammaticUpdate else { return }
            let value = field.stringValue

            pendingWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self, onQueryChange] in
                guard let self else { return }
                guard self.lastSentValue != value else { return }
                self.lastSentValue = value
                onQueryChange(value)
            }
            pendingWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            guard !isProgrammaticUpdate else { return }
            pendingWorkItem?.cancel()
            let value = field.stringValue
            guard lastSentValue != value else { return }
            lastSentValue = value
            onQueryChange(value)
        }
    }
}
