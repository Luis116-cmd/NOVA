import AppKit
import AVFoundation
import Speech

@main
@MainActor
final class NOVAApplication: NSObject, NSApplicationDelegate {
    private let coordinator = NOVACoordinator()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var panel: NOVAPanelController!
    private var avatarWindow: NOVAAvatarWindowController!

    static func main() {
        let app = NSApplication.shared
        let delegate = NOVAApplication()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        avatarWindow = NOVAAvatarWindowController()
        avatarWindow.showOnScreen()

        panel = NOVAPanelController(coordinator: coordinator)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = panel

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "n.circle.fill", accessibilityDescription: "NOVA")
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(toggleNOVA)
        }

        coordinator.onTranscript = { [weak self] transcript in
            self?.panel.updateTranscript(transcript)
            self?.avatarWindow.avatarView.state = .listening
        }
        coordinator.onReply = { [weak self] reply in
            self?.panel.append(role: "NOVA", text: reply)
            self?.avatarWindow.avatarView.state = .speaking
        }
        coordinator.onUserMessage = { [weak self] message in
            self?.panel.append(role: "You", text: message)
            self?.avatarWindow.avatarView.state = .thinking
        }
        coordinator.onListeningChanged = { [weak self] isListening in
            self?.panel.updateListening(isListening)
            self?.statusItem.button?.image = NSImage(
                systemSymbolName: isListening ? "waveform.circle.fill" : "n.circle.fill",
                accessibilityDescription: "NOVA"
            )
            if isListening {
                self?.avatarWindow.avatarView.state = .listening
            } else if self?.avatarWindow.avatarView.state == .listening {
                self?.avatarWindow.avatarView.state = .idle
            }
        }
    }

    @objc private func toggleNOVA() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            avatarWindow.showOnScreen()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stopListening()
        avatarWindow.hide()
    }
}

@MainActor
final class NOVAPanelController: NSViewController, NSTextFieldDelegate {
    private let coordinator: NOVACoordinator
    private let conversation = NSTextView()
    private let input = NSTextField()
    private let listeningButton = NSButton(title: "Start voice", target: nil, action: nil)
    private let stateLabel = NSTextField(labelWithString: "Ready — private actions require your approval.")

    init(coordinator: NOVACoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 560))
        root.wantsLayer = true

        let title = NSTextField(labelWithString: "NOVA")
        title.font = .systemFont(ofSize: 18, weight: .bold)
        let subtitle = NSTextField(labelWithString: "Networked Operations and Virtual Assistant")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 11, weight: .medium)

        conversation.isEditable = false
        conversation.isSelectable = true
        conversation.font = .systemFont(ofSize: 13)
        conversation.textContainerInset = NSSize(width: 12, height: 12)
        conversation.backgroundColor = .controlBackgroundColor
        conversation.string = "NOVA online. Ask for a study guide, flashcards, an approved app, or a conversation.\n"
        let scroll = NSScrollView()
        scroll.documentView = conversation
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        input.placeholderString = "Message NOVA…"
        input.delegate = self
        input.target = self
        input.action = #selector(sendMessage)
        let sendButton = NSButton(title: "Send", target: self, action: #selector(sendMessage))
        sendButton.bezelStyle = .rounded

        listeningButton.target = self
        listeningButton.action = #selector(toggleListening)
        listeningButton.bezelStyle = .rounded
        let settingsButton = NSButton(title: "Settings", target: self, action: #selector(showSettings))
        settingsButton.bezelStyle = .rounded
        stateLabel.font = .systemFont(ofSize: 11)
        stateLabel.textColor = .secondaryLabelColor
        stateLabel.lineBreakMode = .byTruncatingTail

        let header = NSStackView(views: [title, subtitle])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2
        let controls = NSStackView(views: [listeningButton, settingsButton])
        controls.spacing = 8
        let top = NSStackView(views: [header, NSView(), controls])
        top.orientation = .horizontal
        top.alignment = .centerY
        let composer = NSStackView(views: [input, sendButton])
        composer.orientation = .horizontal
        composer.alignment = .centerY
        let stack = NSStackView(views: [top, stateLabel, scroll, composer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 380),
            composer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            input.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        view = root
    }

    @objc private func sendMessage() {
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input.stringValue = ""
        append(role: "You", text: text)
        coordinator.handle(text)
    }

    @objc private func toggleListening() {
        coordinator.isListening ? coordinator.stopListening() : coordinator.startListening()
    }

    @objc private func showSettings() {
        NOVASettingsPresenter.show(from: view.window, coordinator: coordinator)
    }

    func updateTranscript(_ transcript: String) {
        stateLabel.stringValue = transcript.isEmpty ? "Listening…" : "Heard: \(transcript)"
    }

    func updateListening(_ isListening: Bool) {
        listeningButton.title = isListening ? "Stop voice" : "Start voice"
        stateLabel.stringValue = isListening ? "Listening for “NOVA”…" : "Ready — private actions require your approval."
    }

    func append(role: String, text: String) {
        let attributed = NSMutableAttributedString(string: "\n\(role): ")
        attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: .semibold), range: NSRange(location: 0, length: attributed.length))
        attributed.append(NSAttributedString(string: "\(text)\n", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
        conversation.textStorage?.append(attributed)
        conversation.scrollToEndOfDocument(nil)
    }
}
