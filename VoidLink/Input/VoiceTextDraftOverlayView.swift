//
//  VoiceTextDraftOverlayView.swift
//  VoidLink
//
//  A local draft input box for voice dictation (e.g., Doubao / iOS Dictation)
//  and mixed Chinese/English long text. Interim revisions stay local and are
//  only injected into Windows via LiSendUtf8TextEvent upon user confirmation,
//  preventing duplicate interim+final text and bypassing Windows Chinese IME.
//

#if !os(tvOS)
import UIKit

@available(iOS 13.0, *)
@objcMembers
final class VoiceTextDraftOverlayView: UIView, UITextViewDelegate {

    var onClose: (() -> Void)?

    private let containerView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let pasteButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let enterButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private let sendAndCloseButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    private let textView = UITextView()
    private let placeholderLabel = UILabel()

    private var containerBottomConstraint: NSLayoutConstraint?
    private var currentKeyboardHeight: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        registerKeyboardNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        registerKeyboardNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        backgroundColor = .clear
        isExclusiveTouch = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        addSubview(containerView)

        let content = containerView.contentView

        // Header bar
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(headerStack)

        titleLabel.text = "语音 / 长文本发送"
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        configureButton(pasteButton, title: "粘贴", systemImage: "doc.on.clipboard", tint: .white, bg: UIColor.white.withAlphaComponent(0.14))
        pasteButton.addTarget(self, action: #selector(handlePaste), for: .touchUpInside)

        configureButton(clearButton, title: "清空", systemImage: "trash", tint: .white, bg: UIColor.white.withAlphaComponent(0.14))
        clearButton.addTarget(self, action: #selector(handleClear), for: .touchUpInside)

        configureButton(enterButton, title: "回车", systemImage: "return", tint: .white, bg: UIColor.white.withAlphaComponent(0.14))
        enterButton.addTarget(self, action: #selector(handleSendEnter), for: .touchUpInside)

        configureButton(sendButton, title: "发送", systemImage: "paperplane.fill", tint: .white, bg: .systemBlue)
        sendButton.addTarget(self, action: #selector(handleSendKeepOpen), for: .touchUpInside)

        configureButton(sendAndCloseButton, title: "发并关", systemImage: "checkmark.circle.fill", tint: .white, bg: .systemGreen)
        sendAndCloseButton.addTarget(self, action: #selector(handleSendAndClose), for: .touchUpInside)

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = UIColor.white.withAlphaComponent(0.75)
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        closeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(pasteButton)
        headerStack.addArrangedSubview(clearButton)
        headerStack.addArrangedSubview(enterButton)
        headerStack.addArrangedSubview(sendButton)
        headerStack.addArrangedSubview(sendAndCloseButton)
        headerStack.addArrangedSubview(closeButton)

        // TextView
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        textView.textColor = .white
        textView.tintColor = .systemBlue
        textView.font = .systemFont(ofSize: 16)
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .none
        textView.returnKeyType = .default
        content.addSubview(textView)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = "在此使用豆包语音或粘贴中英文内容，确认无误后点「发送」一次性注入 Windows（不会重复或被中文输入法拦截）"
        placeholderLabel.font = .systemFont(ofSize: 13)
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        placeholderLabel.numberOfLines = 2
        textView.addSubview(placeholderLabel)

        let bottomConstraint = containerView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10)
        containerBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -12),
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 720),
            containerView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, constant: -24).withPriority(.defaultHigh),
            bottomConstraint,

            headerStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            headerStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),

            textView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
            textView.heightAnchor.constraint(equalToConstant: 88),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 10),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 15),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -15),
        ])

        updateButtonStates()
    }

    private func configureButton(_ button: UIButton, title: String, systemImage: String, tint: UIColor, bg: UIColor) {
        button.setTitle(" " + title, for: .normal)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)
        button.tintColor = tint
        button.setTitleColor(tint, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.backgroundColor = bg
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 9, bottom: 6, right: 9)
    }

    private func registerKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func handleKeyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = self.window else { return }

        let converted = window.convert(endFrame, to: self)
        let overlap = max(0, bounds.maxY - converted.minY - safeAreaInsets.bottom)
        currentKeyboardHeight = overlap

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        containerBottomConstraint?.constant = -(overlap + 10)
        UIView.animate(withDuration: duration) {
            self.layoutIfNeeded()
        }
    }

    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        currentKeyboardHeight = 0
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        containerBottomConstraint?.constant = -10
        UIView.animate(withDuration: duration) {
            self.layoutIfNeeded()
        }
    }

    func present(in parentView: UIView) {
        if superview !== parentView {
            removeFromSuperview()
            frame = parentView.bounds
            autoresizingMask = [.flexibleWidth, .flexibleHeight]
            parentView.addSubview(self)
        }
        isHidden = false
        alpha = 0
        UIView.animate(withDuration: 0.18) {
            self.alpha = 1
        }
        textView.becomeFirstResponder()
    }

    func dismiss() {
        textView.resignFirstResponder()
        UIView.animate(withDuration: 0.15, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
            self.onClose?()
        })
    }

    // MARK: - Actions

    @objc private func handlePaste() {
        guard let clip = UIPasteboard.general.string, !clip.isEmpty else { return }
        if textView.text.isEmpty {
            textView.text = clip
        } else {
            textView.insertText(clip)
        }
        textViewDidChange(textView)
    }

    @objc private func handleClear() {
        textView.text = ""
        textViewDidChange(textView)
    }

    @objc private func handleSendEnter() {
        DispatchQueue.global(qos: .userInitiated).async {
            LiSendKeyboardEvent(0x0D, Int8(KEY_ACTION_DOWN), 0)
            usleep(40_000)
            LiSendKeyboardEvent(0x0D, Int8(KEY_ACTION_UP), 0)
        }
    }

    @objc private func handleSendKeepOpen() {
        sendCurrentText(closeAfterSend: false)
    }

    @objc private func handleSendAndClose() {
        sendCurrentText(closeAfterSend: true)
    }

    @objc private func handleClose() {
        dismiss()
    }

    private func sendCurrentText(closeAfterSend: Bool) {
        let text = textView.text ?? ""
        guard !text.isEmpty else {
            if closeAfterSend { dismiss() }
            return
        }

        Self.sendUtf8TextSafely(text)
        textView.text = ""
        textViewDidChange(textView)

        if closeAfterSend {
            dismiss()
        }
    }

    /// Sends arbitrarily long UTF-8 text in safe chunks so Sunshine/Windows does not drop packets or overflow buffers.
    @objc static func sendUtf8TextSafely(_ text: String) {
        guard !text.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let maxBytesPerChunk = 256
            var currentChunk = ""
            var currentBytes = 0

            for char in text {
                let s = String(char)
                let byteLen = s.utf8.count
                if currentBytes + byteLen > maxBytesPerChunk && !currentChunk.isEmpty {
                    currentChunk.withCString { ptr in
                        LiSendUtf8TextEvent(ptr, UInt32(strlen(ptr)))
                    }
                    usleep(5_000)
                    currentChunk = s
                    currentBytes = byteLen
                } else {
                    currentChunk.append(char)
                    currentBytes += byteLen
                }
            }

            if !currentChunk.isEmpty {
                currentChunk.withCString { ptr in
                    LiSendUtf8TextEvent(ptr, UInt32(strlen(ptr)))
                }
            }
        }
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        updateButtonStates()
    }

    private func updateButtonStates() {
        let hasText = !(textView.text ?? "").isEmpty
        placeholderLabel.isHidden = hasText
        sendButton.isEnabled = hasText
        sendButton.alpha = hasText ? 1.0 : 0.45
        sendAndCloseButton.isEnabled = hasText
        sendAndCloseButton.alpha = hasText ? 1.0 : 0.45
        clearButton.isEnabled = hasText
        clearButton.alpha = hasText ? 1.0 : 0.45
    }
}

private extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
#endif
