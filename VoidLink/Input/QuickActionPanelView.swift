//
//  QuickActionPanelView.swift
//  VoidLink
//
//  Clean, full-width bottom control bar with:
//  - Push-to-talk (Left Alt hold) & Toggle-to-talk (Right Alt + Space) for PC Doubao voice input using iPad mic
//  - Full expandable transparent PC keyboard (Esc, F1-F12, full QWERTY, arrows, lockable modifiers)
//  - iPad soft keyboard toggle, Trackpad/Touch mode toggle, Paste, Toolbox, Settings, Disconnect
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

    private let backdropView = UIView()
    private let panelView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    private let mainStack = UIStackView()

    private let pttButton = UIButton(type: .system)
    private let toggleVoiceButton = UIButton(type: .system)
    private let pcKeyboardToggleButton = UIButton(type: .system)
    private let touchModeButton = UIButton(type: .system)

    private let pcKeyboardContainer = UIView()
    private var isPCKeyboardVisible = false
    private var isContinuousVoiceActive = false

    // Lockable modifier states on the full PC keyboard
    private var lockedModifiers: Set<Int16> = []
    private var modifierButtons: [Int16: UIButton] = [:]
    private var buttonActions: [ObjectIdentifier: () -> Void] = [:]

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
        layer.zPosition = 2000

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        let bgTap = UITapGestureRecognizer(target: self, action: #selector(dismissPanel))
        backdropView.addGestureRecognizer(bgTap)
        addSubview(backdropView)

        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.layer.cornerRadius = 18
        panelView.layer.masksToBounds = true
        panelView.layer.borderWidth = 1
        panelView.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        addSubview(panelView)

        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        panelView.contentView.addSubview(mainStack)

        // Header bar
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8

        let title = UILabel()
        title.text = "快捷控制中心"
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = UIColor.white.withAlphaComponent(0.9)

        let closeBtn = UIButton(type: .system)
        let closeCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: closeCfg), for: .normal)
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.85)
        closeBtn.addTarget(self, action: #selector(dismissPanel), for: .touchUpInside)
        closeBtn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        closeBtn.heightAnchor.constraint(equalToConstant: 32).isActive = true

        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(closeBtn)
        mainStack.addArrangedSubview(header)

        // Row 1: Voice PTT (Left Alt), Continuous Voice (Right Alt + Space), Full PC Keyboard, iPad Keyboard, Touch Mode
        configurePillButton(pttButton, title: "按住说话 (左Alt)", icon: "mic.fill", bg: .systemBlue)
        pttButton.addTarget(self, action: #selector(handlePttDown), for: .touchDown)
        pttButton.addTarget(self, action: #selector(handlePttUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        configurePillButton(toggleVoiceButton, title: "持续语音 (右Alt+空格)", icon: "waveform", bg: UIColor.white.withAlphaComponent(0.16))
        toggleVoiceButton.addTarget(self, action: #selector(handleToggleContinuousVoice), for: .touchUpInside)

        configurePillButton(pcKeyboardToggleButton, title: "PC全键盘", icon: "keyboard.badge.ellipsis", bg: UIColor.white.withAlphaComponent(0.16))
        pcKeyboardToggleButton.addTarget(self, action: #selector(handleTogglePCKeyboard), for: .touchUpInside)

        let ipadKbBtn = makeActionButton(title: "平板键盘", icon: "keyboard", bg: UIColor.white.withAlphaComponent(0.16)) { [weak self] in
            self?.dismissAndRun { self?.onToggleSoftKeyboard?() }
        }

        configurePillButton(touchModeButton, title: "触控板模式", icon: "hand.point.up.left", bg: UIColor.white.withAlphaComponent(0.16))
        touchModeButton.addTarget(self, action: #selector(handleTouchModeTap), for: .touchUpInside)

        let row1 = makeFilledRow([pttButton, toggleVoiceButton, pcKeyboardToggleButton, ipadKbBtn, touchModeButton])
        mainStack.addArrangedSubview(row1)

        // Row 2: Quick desktop actions (no horizontal scrolling needed)
        let row2 = makeFilledRow([
            makeActionButton(title: "粘贴", icon: "doc.on.clipboard", bg: UIColor.white.withAlphaComponent(0.13)) { [weak self] in
                self?.sendClipboardToWindows()
            },
            makeKeyButton(title: "Alt+Tab", keys: [0x12, 0x09]),
            makeKeyButton(title: "复制", keys: [0x11, 0x43]),
            makeKeyButton(title: "Ctrl+V", keys: [0x11, 0x56]),
            makeKeyButton(title: "Esc", keys: [0x1B]),
            makeKeyButton(title: "Win", keys: [0x5B]),
            makeActionButton(title: "草稿盒", icon: "text.bubble", bg: UIColor.white.withAlphaComponent(0.13)) { [weak self] in
                self?.dismissAndRun { self?.onOpenVoiceDraft?() }
            },
            makeActionButton(title: "工具箱", icon: "wrench", bg: UIColor.white.withAlphaComponent(0.13)) { [weak self] in
                self?.dismissAndRun { self?.onOpenToolbox?() }
            },
            makeActionButton(title: "设置", icon: "gearshape", bg: UIColor.white.withAlphaComponent(0.13)) { [weak self] in
                self?.dismissAndRun { self?.onOpenSettings?() }
            },
            makeActionButton(title: "断开", icon: "power", bg: UIColor.systemRed.withAlphaComponent(0.75)) { [weak self] in
                self?.dismissAndRun { self?.onDisconnect?() }
            }
        ])
        mainStack.addArrangedSubview(row2)

        // Expandable full PC keyboard
        setupFullPCKeyboard()
        pcKeyboardContainer.isHidden = true
        mainStack.addArrangedSubview(pcKeyboardContainer)

        let widthConstraint = panelView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, constant: -32)
        widthConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),

            panelView.centerXAnchor.constraint(equalTo: centerXAnchor),
            panelView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            panelView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            panelView.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            panelView.widthAnchor.constraint(lessThanOrEqualToConstant: 860),
            widthConstraint,

            mainStack.topAnchor.constraint(equalTo: panelView.contentView.topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: panelView.contentView.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Full PC Keyboard Layout

    private func setupFullPCKeyboard() {
        let kbStack = UIStackView()
        kbStack.axis = .vertical
        kbStack.spacing = 4
        kbStack.translatesAutoresizingMaskIntoConstraints = false
        pcKeyboardContainer.addSubview(kbStack)

        // Row F: Esc, F1-F12, Del
        var fButtons: [UIButton] = [makePCKey("Esc", 0x1B, weight: 1.1)]
        for i in 1...12 {
            fButtons.append(makePCKey("F\(i)", Int16(0x70 + i - 1)))
        }
        fButtons.append(makePCKey("Del", 0x2E, weight: 1.1))
        kbStack.addArrangedSubview(makeKeyRow(fButtons, height: 30))

        // Row 1: ` 1-0 - = Backspace
        let numRow = makeKeyRow([
            makePCKey("`", 0xC0), makePCKey("1", 0x31), makePCKey("2", 0x32), makePCKey("3", 0x33),
            makePCKey("4", 0x34), makePCKey("5", 0x35), makePCKey("6", 0x36), makePCKey("7", 0x37),
            makePCKey("8", 0x38), makePCKey("9", 0x39), makePCKey("0", 0x30), makePCKey("-", 0xBD),
            makePCKey("=", 0xBB), makePCKey("⌫", 0x08, weight: 1.6)
        ], height: 32)
        kbStack.addArrangedSubview(numRow)

        // Row 2: Tab Q-P [ ] \
        let qRow = makeKeyRow([
            makePCKey("Tab", 0x09, weight: 1.4),
            makePCKey("Q", 0x51), makePCKey("W", 0x57), makePCKey("E", 0x45), makePCKey("R", 0x52),
            makePCKey("T", 0x54), makePCKey("Y", 0x59), makePCKey("U", 0x55), makePCKey("I", 0x49),
            makePCKey("O", 0x4F), makePCKey("P", 0x50), makePCKey("[", 0xDB), makePCKey("]", 0xDD),
            makePCKey("\\", 0xDC, weight: 1.2)
        ], height: 32)
        kbStack.addArrangedSubview(qRow)

        // Row 3: Caps A-L ; ' Enter
        let aRow = makeKeyRow([
            makePCKey("Caps", 0x14, weight: 1.5),
            makePCKey("A", 0x41), makePCKey("S", 0x53), makePCKey("D", 0x44), makePCKey("F", 0x46),
            makePCKey("G", 0x47), makePCKey("H", 0x48), makePCKey("J", 0x4A), makePCKey("K", 0x4B),
            makePCKey("L", 0x4C), makePCKey(";", 0xBA), makePCKey("'", 0xDE),
            makePCKey("Enter", 0x0D, weight: 1.8)
        ], height: 32)
        kbStack.addArrangedSubview(aRow)

        // Row 4: Shift Z-M , . / Up PgUp
        let zRow = makeKeyRow([
            makeModifierKey("Shift", 0xA0, weight: 1.7),
            makePCKey("Z", 0x5A), makePCKey("X", 0x58), makePCKey("C", 0x43), makePCKey("V", 0x56),
            makePCKey("B", 0x42), makePCKey("N", 0x4E), makePCKey("M", 0x4D), makePCKey(",", 0xBC),
            makePCKey(".", 0xBE), makePCKey("/", 0xBF),
            makePCKey("↑", 0x26, weight: 1.1), makePCKey("Home", 0x24, weight: 1.1), makePCKey("End", 0x23, weight: 1.1)
        ], height: 32)
        kbStack.addArrangedSubview(zRow)

        // Row 5: Ctrl Win Alt Space RAlt Left Down Right
        let bottomRow = makeKeyRow([
            makeModifierKey("Ctrl", 0xA2, weight: 1.3),
            makeModifierKey("Win", 0x5B, weight: 1.2),
            makeModifierKey("Alt", 0xA4, weight: 1.2),
            makePCKey("Space", 0x20, weight: 4.5),
            makeModifierKey("RAlt", 0xA5, weight: 1.2),
            makePCKey("←", 0x25, weight: 1.1),
            makePCKey("↓", 0x28, weight: 1.1),
            makePCKey("→", 0x27, weight: 1.1),
            makePCKey("PgUp", 0x21, weight: 1.1),
            makePCKey("PgDn", 0x22, weight: 1.1)
        ], height: 32)
        kbStack.addArrangedSubview(bottomRow)

        NSLayoutConstraint.activate([
            kbStack.topAnchor.constraint(equalTo: pcKeyboardContainer.topAnchor, constant: 4),
            kbStack.leadingAnchor.constraint(equalTo: pcKeyboardContainer.leadingAnchor),
            kbStack.trailingAnchor.constraint(equalTo: pcKeyboardContainer.trailingAnchor),
            kbStack.bottomAnchor.constraint(equalTo: pcKeyboardContainer.bottomAnchor),
        ])
    }

    private func makeKeyRow(_ buttons: [UIButton], height: CGFloat) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = .fillProportionally
        row.heightAnchor.constraint(equalToConstant: height).isActive = true
        return row
    }

    private func makeFilledRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fillProportionally
        row.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return row
    }

    private func makePCKey(_ title: String, _ code: Int16, weight: CGFloat = 1.0) -> UIButton {
        let btn = makeActionButton(title: title, icon: nil, bg: UIColor.white.withAlphaComponent(0.16)) { [weak self] in
            self?.sendPCKeyWithModifiers(code)
        }
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        btn.layer.cornerRadius = 6
        if weight != 1.0 {
            btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 36 * weight).isActive = true
        }
        return btn
    }

    private func makeModifierKey(_ title: String, _ code: Int16, weight: CGFloat = 1.2) -> UIButton {
        let btn = makeActionButton(title: title, icon: nil, bg: UIColor.white.withAlphaComponent(0.22)) { [weak self] in
            self?.toggleModifierKey(code)
        }
        btn.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        btn.layer.cornerRadius = 6
        btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 36 * weight).isActive = true
        modifierButtons[code] = btn
        return btn
    }

    private func toggleModifierKey(_ code: Int16) {
        let vk = Int16(bitPattern: 0x8000 | UInt16(bitPattern: code))
        let mod = modifierFlag(for: code)
        if lockedModifiers.contains(code) {
            lockedModifiers.remove(code)
            modifierButtons[code]?.backgroundColor = UIColor.white.withAlphaComponent(0.22)
            DispatchQueue.global(qos: .userInitiated).async {
                LiSendKeyboardEvent(vk, Int8(KEY_ACTION_UP), mod)
            }
        } else {
            lockedModifiers.insert(code)
            modifierButtons[code]?.backgroundColor = .systemBlue
            DispatchQueue.global(qos: .userInitiated).async {
                LiSendKeyboardEvent(vk, Int8(KEY_ACTION_DOWN), mod)
            }
        }
    }

    private func sendPCKeyWithModifiers(_ code: Int16) {
        let activeMods = Array(lockedModifiers)
        var modMask: Int8 = 0
        for m in activeMods {
            modMask |= modifierFlag(for: m)
            modifierButtons[m]?.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        }
        if !activeMods.isEmpty {
            lockedModifiers.removeAll()
        }
        let vk = Int16(bitPattern: 0x8000 | UInt16(bitPattern: code))
        DispatchQueue.global(qos: .userInitiated).async {
            LiSendKeyboardEvent(vk, Int8(KEY_ACTION_DOWN), modMask)
            usleep(30_000)
            LiSendKeyboardEvent(vk, Int8(KEY_ACTION_UP), modMask)
            for m in activeMods {
                usleep(10_000)
                let mvk = Int16(bitPattern: 0x8000 | UInt16(bitPattern: m))
                LiSendKeyboardEvent(mvk, Int8(KEY_ACTION_UP), 0)
            }
        }
    }

    private func releaseAllLockedModifiers() {
        guard !lockedModifiers.isEmpty else { return }
        let mods = Array(lockedModifiers)
        lockedModifiers.removeAll()
        for m in mods {
            modifierButtons[m]?.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            for m in mods {
                let mvk = Int16(bitPattern: 0x8000 | UInt16(bitPattern: m))
                LiSendKeyboardEvent(mvk, Int8(KEY_ACTION_UP), 0)
            }
        }
    }

    // MARK: - Voice & Action Handlers

    @objc private func handlePttDown() {
        pttButton.backgroundColor = .systemRed
        pttButton.setTitle(" 松开结束说话", for: .normal)
        let vk = Int16(bitPattern: 0x8000 | 0x00A4) // Left Alt
        DispatchQueue.global(qos: .userInitiated).async {
            LiSendKeyboardEvent(vk, Int8(KEY_ACTION_DOWN), Int8(MODIFIER_ALT))
        }
    }

    @objc private func handlePttUp() {
        pttButton.backgroundColor = .systemBlue
        pttButton.setTitle(" 按住说话 (左Alt)", for: .normal)
        let vk = Int16(bitPattern: 0x8000 | 0x00A4)
        DispatchQueue.global(qos: .userInitiated).async {
            LiSendKeyboardEvent(vk, Int8(KEY_ACTION_UP), 0)
        }
    }

    @objc private func handleToggleContinuousVoice() {
        isContinuousVoiceActive.toggle()
        if isContinuousVoiceActive {
            toggleVoiceButton.backgroundColor = .systemRed
            toggleVoiceButton.setTitle(" 点此结束语音", for: .normal)
            sendCombo([0xA5, 0x20]) // Right Alt + Space
        } else {
            toggleVoiceButton.backgroundColor = UIColor.white.withAlphaComponent(0.16)
            toggleVoiceButton.setTitle(" 持续语音 (右Alt+空格)", for: .normal)
            sendCombo([0x20]) // Space to stop
        }
    }

    @objc private func handleTogglePCKeyboard() {
        isPCKeyboardVisible.toggle()
        pcKeyboardContainer.isHidden = !isPCKeyboardVisible
        pcKeyboardToggleButton.backgroundColor = isPCKeyboardVisible ? .systemBlue : UIColor.white.withAlphaComponent(0.16)
        UIView.animate(withDuration: 0.16) {
            self.layoutIfNeeded()
        }
    }

    @objc private func handleTouchModeTap() {
        onToggleTouchMode?()
        refreshTouchModeTitle()
    }

    private func refreshTouchModeTitle() {
        let isRelative = currentTouchModeIsRelative?() ?? true
        touchModeButton.setTitle(isRelative ? " 触控板" : " 原生触屏", for: .normal)
    }

    private func sendClipboardToWindows() {
        guard let clip = UIPasteboard.general.string, !clip.isEmpty else { return }
        VoiceTextDraftOverlayView.sendUtf8TextSafely(clip)
    }

    private func modifierFlag(for code: Int16) -> Int8 {
        switch code {
        case 0x10, 0xA0, 0xA1: return Int8(MODIFIER_SHIFT)
        case 0x11, 0xA2, 0xA3: return Int8(MODIFIER_CTRL)
        case 0x12, 0xA4, 0xA5: return Int8(MODIFIER_ALT)
        case 0x5B, 0x5C: return Int8(MODIFIER_META)
        default: return 0
        }
    }

    private func sendCombo(_ keys: [Int16]) {
        guard !keys.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var activeMask: Int8 = 0
            for k in keys {
                activeMask |= self.modifierFlag(for: k)
                let vk = Int16(bitPattern: 0x8000 | UInt16(bitPattern: k))
                LiSendKeyboardEvent(vk, Int8(KEY_ACTION_DOWN), activeMask)
                usleep(12_000)
            }
            usleep(35_000)
            for k in keys.reversed() {
                activeMask &= ~self.modifierFlag(for: k)
                let vk = Int16(bitPattern: 0x8000 | UInt16(bitPattern: k))
                LiSendKeyboardEvent(vk, Int8(KEY_ACTION_UP), activeMask)
                usleep(12_000)
            }
        }
    }

    // MARK: - Helpers & Presentation

    private func makeActionButton(title: String, icon: String?, bg: UIColor, handler: @escaping () -> Void) -> UIButton {
        let btn = UIButton(type: .system)
        configurePillButton(btn, title: title, icon: icon, bg: bg)
        buttonActions[ObjectIdentifier(btn)] = handler
        btn.addTarget(self, action: #selector(handleDynamicButton(_:)), for: .touchUpInside)
        return btn
    }

    private func makeKeyButton(title: String, keys: [Int16]) -> UIButton {
        return makeActionButton(title: title, icon: nil, bg: UIColor.white.withAlphaComponent(0.13)) { [weak self] in
            self?.sendCombo(keys)
        }
    }

    private func configurePillButton(_ btn: UIButton, title: String, icon: String?, bg: UIColor) {
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
        btn.titleLabel?.lineBreakMode = .byClipping
        btn.backgroundColor = bg
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
    }

    @objc private func handleDynamicButton(_ sender: UIButton) {
        buttonActions[ObjectIdentifier(sender)]?()
    }

    func present(in parentView: UIView) {
        refreshTouchModeTitle()
        if superview !== parentView {
            removeFromSuperview()
            frame = parentView.bounds
            autoresizingMask = [.flexibleWidth, .flexibleHeight]
            parentView.addSubview(self)
        } else {
            parentView.bringSubviewToFront(self)
        }
        isHidden = false
        alpha = 0
        UIView.animate(withDuration: 0.12) {
            self.alpha = 1
        }
    }

    @objc func dismissPanel() {
        releaseAllLockedModifiers()
        UIView.animate(withDuration: 0.1, animations: {
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
