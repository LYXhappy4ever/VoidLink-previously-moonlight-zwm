//
//  QuickActionPanelView.swift
//  VoidLink
//
//  A single unified, zero-configuration quick control panel opened from the
//  floating corner button. Replaces scattered buttons and layout editors for
//  common Windows desktop & gaming actions, and includes an inline F1-F12 /
//  arrow mini-keypad.
//

#if !os(tvOS)
import UIKit

@available(iOS 13.0, *)
@objcMembers
final class QuickActionPanelView: UIView {

    var onOpenVoiceDraft: (() -> Void)?
    var onToggleSoftKeyboard: (() -> Void)?
    var onToggleTouchMode: (() -> Void)?
    var onOpenToolbox: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var currentTouchModeIsRelative: (() -> Bool)?

    private let backdropButton = UIButton(type: .custom)
    private let panelView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    private let mainStack = UIStackView()
    private let touchModeButton = UIButton(type: .system)
    private let miniKeypadContainer = UIView()
    private var isMiniKeypadVisible = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .clear

        backdropButton.translatesAutoresizingMaskIntoConstraints = false
        backdropButton.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        backdropButton.addTarget(self, action: #selector(dismissPanel), for: .touchUpInside)
        addSubview(backdropButton)

        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.layer.cornerRadius = 18
        panelView.layer.masksToBounds = true
        panelView.layer.borderWidth = 1
        panelView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        addSubview(panelView)

        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        panelView.contentView.addSubview(mainStack)

        // Header
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        let title = UILabel()
        title.text = "快捷控制中心"
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = UIColor.white.withAlphaComponent(0.9)
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.7)
        closeBtn.addTarget(self, action: #selector(dismissPanel), for: .touchUpInside)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(closeBtn)
        mainStack.addArrangedSubview(header)

        // Row 1: Core actions
        let row1 = makeRow([
            makeActionButton(title: "语音发送", icon: "waveform.and.mic", bg: .systemBlue) { [weak self] in
                self?.dismissAndRun { self?.onOpenVoiceDraft?() }
            },
            makeActionButton(title: "软键盘", icon: "keyboard", bg: UIColor.white.withAlphaComponent(0.16)) { [weak self] in
                self?.dismissAndRun { self?.onToggleSoftKeyboard?() }
            },
            makeActionButton(title: "F1~F12/方向", icon: "square.grid.3x3", bg: UIColor.white.withAlphaComponent(0.16)) { [weak self] in
                self?.toggleMiniKeypad()
            },
            makeActionButton(title: "粘贴剪贴板", icon: "doc.on.clipboard", bg: UIColor.white.withAlphaComponent(0.16)) { [weak self] in
                self?.sendClipboardToWindows()
                self?.dismissPanel()
            },
            makeActionButton(title: "Win+H语音", icon: "mic.fill", bg: UIColor.white.withAlphaComponent(0.16)) { [weak self] in
                self?.sendCombo([0x5B, 0x48])
                self?.dismissPanel()
            }
        ])
        mainStack.addArrangedSubview(row1)

        // Row 2: Desktop shortcuts & stream control
        configureActionButton(touchModeButton, title: "触控板模式", icon: "hand.point.up.left", bg: UIColor.white.withAlphaComponent(0.14))
        touchModeButton.addTarget(self, action: #selector(handleTouchModeTap), for: .touchUpInside)

        let row2 = makeRow([
            touchModeButton,
            makeKeyButton(title: "Alt+Tab", keys: [0x12, 0x09]),
            makeKeyButton(title: "Esc", keys: [0x1B]),
            makeKeyButton(title: "Win", keys: [0x5B]),
            makeKeyButton(title: "复制", keys: [0x11, 0x43]),
            makeKeyButton(title: "粘贴", keys: [0x11, 0x56]),
            makeActionButton(title: "工具箱", icon: "wrench.and.screwdriver", bg: UIColor.white.withAlphaComponent(0.14)) { [weak self] in
                self?.dismissAndRun { self?.onOpenToolbox?() }
            },
            makeActionButton(title: "设置", icon: "gearshape", bg: UIColor.white.withAlphaComponent(0.14)) { [weak self] in
                self?.dismissAndRun { self?.onOpenSettings?() }
            },
            makeActionButton(title: "断开", icon: "power", bg: UIColor.systemRed.withAlphaComponent(0.75)) { [weak self] in
                self?.dismissAndRun { self?.onDisconnect?() }
            }
        ])
        mainStack.addArrangedSubview(row2)

        // Mini F1-F12 & Arrow keypad (hidden by default)
        setupMiniKeypad()
        miniKeypadContainer.isHidden = true
        mainStack.addArrangedSubview(miniKeypadContainer)

        NSLayoutConstraint.activate([
            backdropButton.topAnchor.constraint(equalTo: topAnchor),
            backdropButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            panelView.centerXAnchor.constraint(equalTo: centerXAnchor),
            panelView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -18),
            panelView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            panelView.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            panelView.widthAnchor.constraint(lessThanOrEqualToConstant: 700),

            mainStack.topAnchor.constraint(equalTo: panelView.contentView.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor, constant: -14),
            mainStack.bottomAnchor.constraint(equalTo: panelView.contentView.bottomAnchor, constant: -12),
        ])
    }

    private func setupMiniKeypad() {
        let keypadStack = UIStackView()
        keypadStack.axis = .vertical
        keypadStack.spacing = 6
        keypadStack.translatesAutoresizingMaskIntoConstraints = false
        miniKeypadContainer.addSubview(keypadStack)

        let fRow1 = makeRow((1...6).map { i in makeKeyButton(title: "F\(i)", keys: [Int16(0x70 + i - 1)]) })
        let fRow2 = makeRow((7...12).map { i in makeKeyButton(title: "F\(i)", keys: [Int16(0x70 + i - 1)]) })
        let navRow = makeRow([
            makeKeyButton(title: "←", keys: [0x25]),
            makeKeyButton(title: "↑", keys: [0x26]),
            makeKeyButton(title: "↓", keys: [0x28]),
            makeKeyButton(title: "→", keys: [0x27]),
            makeKeyButton(title: "Tab", keys: [0x09]),
            makeKeyButton(title: "Del", keys: [0x2E]),
            makeKeyButton(title: "Home", keys: [0x24]),
            makeKeyButton(title: "End", keys: [0x23]),
            makeKeyButton(title: "PgUp", keys: [0x21]),
            makeKeyButton(title: "PgDn", keys: [0x22])
        ])

        keypadStack.addArrangedSubview(fRow1)
        keypadStack.addArrangedSubview(fRow2)
        keypadStack.addArrangedSubview(navRow)

        NSLayoutConstraint.activate([
            keypadStack.topAnchor.constraint(equalTo: miniKeypadContainer.topAnchor, constant: 4),
            keypadStack.leadingAnchor.constraint(equalTo: miniKeypadContainer.leadingAnchor),
            keypadStack.trailingAnchor.constraint(equalTo: miniKeypadContainer.trailingAnchor),
            keypadStack.bottomAnchor.constraint(equalTo: miniKeypadContainer.bottomAnchor),
        ])
    }

    private func makeRow(_ buttons: [UIButton]) -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 36),
        ])
        return scroll
    }

    private var buttonActions: [ObjectIdentifier: () -> Void] = [:]

    private func makeActionButton(title: String, icon: String?, bg: UIColor, handler: @escaping () -> Void) -> UIButton {
        let btn = UIButton(type: .system)
        configureActionButton(btn, title: title, icon: icon, bg: bg)
        buttonActions[ObjectIdentifier(btn)] = handler
        btn.addTarget(self, action: #selector(handleDynamicButton(_:)), for: .touchUpInside)
        return btn
    }

    private func makeKeyButton(title: String, keys: [Int16]) -> UIButton {
        return makeActionButton(title: title, icon: nil, bg: UIColor.white.withAlphaComponent(0.14)) { [weak self] in
            self?.sendCombo(keys)
        }
    }

    private func configureActionButton(_ btn: UIButton, title: String, icon: String?, bg: UIColor) {
        if let icon {
            let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
            btn.setTitle(" " + title, for: .normal)
        } else {
            btn.setTitle(title, for: .normal)
        }
        btn.tintColor = .white
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        btn.backgroundColor = bg
        btn.layer.cornerRadius = 9
        btn.contentEdgeInsets = UIEdgeInsets(top: 7, left: 11, bottom: 7, right: 11)
    }

    @objc private func handleDynamicButton(_ sender: UIButton) {
        buttonActions[ObjectIdentifier(sender)]?()
    }

    @objc private func handleTouchModeTap() {
        onToggleTouchMode?()
        refreshTouchModeTitle()
    }

    private func refreshTouchModeTitle() {
        let isRelative = currentTouchModeIsRelative?() ?? true
        touchModeButton.setTitle(isRelative ? " 当前:触控板" : " 当前:原生触屏", for: .normal)
    }

    private func toggleMiniKeypad() {
        isMiniKeypadVisible.toggle()
        miniKeypadContainer.isHidden = !isMiniKeypadVisible
        UIView.animate(withDuration: 0.18) {
            self.layoutIfNeeded()
        }
    }

    private func sendClipboardToWindows() {
        guard let clip = UIPasteboard.general.string, !clip.isEmpty else { return }
        VoiceTextDraftOverlayView.sendUtf8TextSafely(clip)
    }

    private func sendCombo(_ keys: [Int16]) {
        guard !keys.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            for k in keys {
                LiSendKeyboardEvent(k, Int8(KEY_ACTION_DOWN), 0)
                usleep(12_000)
            }
            usleep(35_000)
            for k in keys.reversed() {
                LiSendKeyboardEvent(k, Int8(KEY_ACTION_UP), 0)
                usleep(12_000)
            }
        }
    }

    func present(in parentView: UIView) {
        refreshTouchModeTitle()
        if superview !== parentView {
            removeFromSuperview()
            frame = parentView.bounds
            autoresizingMask = [.flexibleWidth, .flexibleHeight]
            parentView.addSubview(self)
        }
        isHidden = false
        alpha = 0
        UIView.animate(withDuration: 0.15) {
            self.alpha = 1
        }
    }

    @objc func dismissPanel() {
        UIView.animate(withDuration: 0.12, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    private func dismissAndRun(_ block: @escaping () -> Void) {
        dismissPanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            block()
        }
    }
}
#endif
