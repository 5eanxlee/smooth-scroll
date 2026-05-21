import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import SmoothScrollCore

private enum DefaultsKey {
    static let enabled = "enabled"
    static let pixelsPerWheelStep = "pixelsPerWheelStep"
    static let timeConstant = "timeConstant"
    static let verticalMultiplier = "verticalMultiplier"
    static let horizontalMultiplier = "horizontalMultiplier"
    static let acceleration = "acceleration"
    static let reverseVertical = "reverseVertical"
    static let reverseHorizontal = "reverseHorizontal"
    static let bypassModifier = "bypassModifier"
    static let precisionModifier = "precisionModifier"
    static let boostModifier = "boostModifier"
    static let showInMenuBar = "showInMenuBar"
    static let excludedBundleIdentifiers = "excludedBundleIdentifiers"
    static let launchAtLogin = "launchAtLogin"
    static let launchAgentConfigured = "launchAgentConfigured"
}

fileprivate enum BypassModifier: String, CaseIterable {
    case none
    case shift
    case option
    case control
    case command

    var title: String {
        switch self {
        case .none:
            "None"
        case .shift:
            "Shift"
        case .option:
            "Option"
        case .control:
            "Control"
        case .command:
            "Command"
        }
    }

    var eventFlag: CGEventFlags? {
        switch self {
        case .none:
            nil
        case .shift:
            .maskShift
        case .option:
            .maskAlternate
        case .control:
            .maskControl
        case .command:
            .maskCommand
        }
    }

    func matches(_ flags: CGEventFlags) -> Bool {
        guard let eventFlag else {
            return false
        }
        return flags.contains(eventFlag)
    }
}

fileprivate struct ScrollPreset: Equatable {
    let title: String
    let pixelsPerWheelStep: Double
    let timeConstant: Double
    let acceleration: Double

    static let all: [ScrollPreset] = [
        ScrollPreset(title: "Precise", pixelsPerWheelStep: 48.0, timeConstant: 0.12, acceleration: 0.0),
        ScrollPreset(title: "Balanced", pixelsPerWheelStep: 72.0, timeConstant: 0.18, acceleration: 0.0),
        ScrollPreset(title: "Fast", pixelsPerWheelStep: 120.0, timeConstant: 0.16, acceleration: 0.35),
        ScrollPreset(title: "Glide", pixelsPerWheelStep: 88.0, timeConstant: 0.32, acceleration: 0.15)
    ]
}

final class SettingsStore {
    static let didChangeNotification = Notification.Name("SettingsStoreDidChangeNotification")

    private let defaults = UserDefaults(suiteName: "com.local.SmoothScroll") ?? .standard

    var onChange: (() -> Void)?

    var enabled: Bool {
        get { bool(forKey: DefaultsKey.enabled, defaultValue: true) }
        set { set(newValue, forKey: DefaultsKey.enabled) }
    }

    var pixelsPerWheelStep: Double {
        get { double(forKey: DefaultsKey.pixelsPerWheelStep, defaultValue: 72.0) }
        set { set(newValue.clamped(to: 24.0 ... 180.0), forKey: DefaultsKey.pixelsPerWheelStep) }
    }

    var timeConstant: Double {
        get { double(forKey: DefaultsKey.timeConstant, defaultValue: 0.18) }
        set { set(newValue.clamped(to: 0.06 ... 0.50), forKey: DefaultsKey.timeConstant) }
    }

    var verticalMultiplier: Double {
        get { double(forKey: DefaultsKey.verticalMultiplier, defaultValue: 1.0) }
        set { set(newValue.clamped(to: 0.25 ... 2.0), forKey: DefaultsKey.verticalMultiplier) }
    }

    var horizontalMultiplier: Double {
        get { double(forKey: DefaultsKey.horizontalMultiplier, defaultValue: 1.0) }
        set { set(newValue.clamped(to: 0.25 ... 2.0), forKey: DefaultsKey.horizontalMultiplier) }
    }

    var acceleration: Double {
        get { double(forKey: DefaultsKey.acceleration, defaultValue: 0.0) }
        set { set(newValue.clamped(to: 0.0 ... 2.0), forKey: DefaultsKey.acceleration) }
    }

    var reverseVertical: Bool {
        get { bool(forKey: DefaultsKey.reverseVertical, defaultValue: false) }
        set { set(newValue, forKey: DefaultsKey.reverseVertical) }
    }

    var reverseHorizontal: Bool {
        get { bool(forKey: DefaultsKey.reverseHorizontal, defaultValue: false) }
        set { set(newValue, forKey: DefaultsKey.reverseHorizontal) }
    }

    fileprivate var bypassModifier: BypassModifier {
        get {
            let rawValue = string(forKey: DefaultsKey.bypassModifier, defaultValue: BypassModifier.option.rawValue)
            return BypassModifier(rawValue: rawValue) ?? .option
        }
        set { set(newValue.rawValue, forKey: DefaultsKey.bypassModifier) }
    }

    fileprivate var precisionModifier: BypassModifier {
        get {
            let rawValue = string(forKey: DefaultsKey.precisionModifier, defaultValue: BypassModifier.shift.rawValue)
            return BypassModifier(rawValue: rawValue) ?? .shift
        }
        set { set(newValue.rawValue, forKey: DefaultsKey.precisionModifier) }
    }

    fileprivate var boostModifier: BypassModifier {
        get {
            let rawValue = string(forKey: DefaultsKey.boostModifier, defaultValue: BypassModifier.command.rawValue)
            return BypassModifier(rawValue: rawValue) ?? .command
        }
        set { set(newValue.rawValue, forKey: DefaultsKey.boostModifier) }
    }

    var showInMenuBar: Bool {
        get { bool(forKey: DefaultsKey.showInMenuBar, defaultValue: true) }
        set { set(newValue, forKey: DefaultsKey.showInMenuBar) }
    }

    var excludedBundleIdentifiers: [String] {
        get { stringArray(forKey: DefaultsKey.excludedBundleIdentifiers, defaultValue: []) }
        set {
            let normalized = Array(Set(newValue.filter { !$0.isEmpty })).sorted()
            defaults.set(normalized, forKey: DefaultsKey.excludedBundleIdentifiers)
            notifyChange()
        }
    }

    var launchAtLogin: Bool {
        get { bool(forKey: DefaultsKey.launchAtLogin, defaultValue: true) }
        set { set(newValue, forKey: DefaultsKey.launchAtLogin) }
    }

    var launchAgentConfigured: Bool {
        get { bool(forKey: DefaultsKey.launchAgentConfigured, defaultValue: false) }
        set { set(newValue, forKey: DefaultsKey.launchAgentConfigured) }
    }

    var physicsConfiguration: ScrollPhysicsConfiguration {
        ScrollPhysicsConfiguration(
            pixelsPerWheelStep: pixelsPerWheelStep,
            timeConstant: timeConstant,
            verticalMultiplier: verticalMultiplier,
            horizontalMultiplier: horizontalMultiplier,
            acceleration: acceleration
        )
    }

    func resetScrolling() {
        pixelsPerWheelStep = 72.0
        timeConstant = 0.18
        verticalMultiplier = 1.0
        horizontalMultiplier = 1.0
        acceleration = 0.0
        reverseVertical = false
        reverseHorizontal = false
    }

    fileprivate func applyPreset(_ preset: ScrollPreset) {
        pixelsPerWheelStep = preset.pixelsPerWheelStep
        timeConstant = preset.timeConstant
        verticalMultiplier = 1.0
        horizontalMultiplier = 1.0
        acceleration = preset.acceleration
    }

    func addExcludedBundleIdentifier(_ bundleIdentifier: String) {
        var bundleIdentifiers = excludedBundleIdentifiers
        guard !bundleIdentifiers.contains(bundleIdentifier) else {
            return
        }
        bundleIdentifiers.append(bundleIdentifier)
        excludedBundleIdentifiers = bundleIdentifiers
    }

    func removeExcludedBundleIdentifier(_ bundleIdentifier: String) {
        excludedBundleIdentifiers = excludedBundleIdentifiers.filter { $0 != bundleIdentifier }
    }

    func isExcluded(bundleIdentifier: String) -> Bool {
        excludedBundleIdentifiers.contains(bundleIdentifier)
    }

    private func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    private func double(forKey key: String, defaultValue: Double) -> Double {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.double(forKey: key)
    }

    private func string(forKey key: String, defaultValue: String) -> String {
        guard let value = defaults.string(forKey: key) else {
            return defaultValue
        }
        return value
    }

    private func stringArray(forKey key: String, defaultValue: [String]) -> [String] {
        guard let value = defaults.stringArray(forKey: key) else {
            return defaultValue
        }
        return value
    }

    private func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        notifyChange()
    }

    private func set(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
        notifyChange()
    }

    private func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
        notifyChange()
    }

    private func notifyChange() {
        onChange?()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}

final class ApplicationMonitor: NSObject {
    var onChange: (() -> Void)?

    private let ownBundleIdentifier = Bundle.main.bundleIdentifier
    private(set) var lastApplication: NSRunningApplication?

    override init() {
        super.init()
        remember(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    var currentTargetApplication: NSRunningApplication? {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if isUserApplication(frontmostApplication) {
            return frontmostApplication
        }
        return lastApplication
    }

    var currentTargetBundleIdentifier: String? {
        currentTargetApplication?.bundleIdentifier
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        remember(application)
    }

    private func remember(_ application: NSRunningApplication?) {
        guard isUserApplication(application) else {
            return
        }
        lastApplication = application
        onChange?()
    }

    private func isUserApplication(_ application: NSRunningApplication?) -> Bool {
        guard let application, application.bundleIdentifier != ownBundleIdentifier else {
            return false
        }
        return application.activationPolicy == .regular
    }
}

enum ScrollStatus: Equatable {
    case running
    case disabled
    case permissionNeeded
    case eventTapFailed

    var title: String {
        switch self {
        case .running:
            "Active"
        case .disabled:
            "Off"
        case .permissionNeeded:
            "Needs Accessibility"
        case .eventTapFailed:
            "Event Tap Failed"
        }
    }
}

final class ScrollController {
    private static let syntheticEventMarker: Int64 = 0x4C53534D_5343524C

    private let settings: SettingsStore
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: DispatchSourceTimer?
    private var permissionRetryTimer: DispatchSourceTimer?
    private var lastTick: TimeInterval?
    private var engine = ScrollPhysicsEngine()
    private let eventSource = CGEventSource(stateID: .hidSystemState)

    private(set) var status: ScrollStatus = .disabled {
        didSet {
            if oldValue != status {
                notifyStatusObservers()
            }
        }
    }

    private var statusObservers: [(ScrollStatus) -> Void] = []

    init(settings: SettingsStore) {
        self.settings = settings
        self.engine.configuration = settings.physicsConfiguration
    }

    func addStatusObserver(_ observer: @escaping (ScrollStatus) -> Void) {
        statusObservers.append(observer)
        observer(status)
    }

    func applySettings() {
        engine.configuration = settings.physicsConfiguration
        if settings.enabled {
            start()
        } else {
            stop()
            status = .disabled
        }
    }

    func start() {
        stopEventTap()

        guard settings.enabled else {
            status = .disabled
            return
        }

        guard AXIsProcessTrusted() else {
            status = .permissionNeeded
            startPermissionRetryTimerIfNeeded()
            return
        }
        stopPermissionRetryTimer()

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            status = .eventTapFailed
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        status = .running
    }

    func stop() {
        stopTimer()
        stopPermissionRetryTimer()
        stopEventTap()
        engine.reset()
    }

    func requestAccessibilityPermission() {
        let promptKey = "AXTrustedCheckOptionPrompt"
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    fileprivate func handle(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        guard settings.enabled else {
            return Unmanaged.passUnretained(event)
        }

        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        if isContinuous {
            return Unmanaged.passUnretained(event)
        }

        let vertical = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let horizontal = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        guard vertical != 0 || horizontal != 0 else {
            return Unmanaged.passUnretained(event)
        }

        engine.addWheelDelta(
            horizontalLines: Double(horizontal),
            verticalLines: Double(vertical)
        )
        startTimerIfNeeded()
        return nil
    }

    private func startTimerIfNeeded() {
        guard timer == nil else {
            return
        }

        lastTick = nil
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        self.timer = timer
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let deltaTime = lastTick.map { now - $0 } ?? (1.0 / 120.0)
        lastTick = now

        let frame = engine.nextFrame(deltaTime: deltaTime)
        if frame.hasPixels {
            post(frame: frame)
        }

        if !engine.isActive {
            stopTimer()
        }
    }

    private func post(frame: ScrollFrame) {
        let wheelCount: UInt32 = frame.pixelsX == 0 ? 1 : 2
        guard let event = CGEvent(
            scrollWheelEvent2Source: eventSource,
            units: .pixel,
            wheelCount: wheelCount,
            wheel1: frame.pixelsY,
            wheel2: frame.pixelsX,
            wheel3: 0
        ) else {
            return
        }

        event.setIntegerValueField(CGEventField.eventSourceUserData, value: Self.syntheticEventMarker)
        event.setIntegerValueField(CGEventField.scrollWheelEventIsContinuous, value: 1)
        event.post(tap: CGEventTapLocation.cghidEventTap)
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        lastTick = nil
    }

    private func startPermissionRetryTimerIfNeeded() {
        guard permissionRetryTimer == nil else {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(2), repeating: .seconds(2), leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self, self.settings.enabled else {
                self?.stopPermissionRetryTimer()
                return
            }
            if AXIsProcessTrusted() {
                self.start()
            }
        }
        timer.resume()
        permissionRetryTimer = timer
    }

    private func stopPermissionRetryTimer() {
        permissionRetryTimer?.cancel()
        permissionRetryTimer = nil
    }

    private func stopEventTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func notifyStatusObservers() {
        for observer in statusObservers {
            observer(status)
        }
    }
}

private func scrollEventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let controller = Unmanaged<ScrollController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(proxy: proxy, type: type, event: event)
}

final class LaunchAgentManager {
    private let label = "com.local.SmoothScroll"

    var canInstallForCurrentBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    var pointsAtCurrentBundle: Bool {
        installedBundlePath == Bundle.main.bundleURL.path
    }

    var installedBundlePath: String? {
        guard
            let data = try? Data(contentsOf: agentURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dictionary = plist as? [String: Any],
            let arguments = dictionary["ProgramArguments"] as? [String],
            let path = arguments.last
        else {
            return nil
        }
        return path
    }

    func installForCurrentBundle() throws {
        guard canInstallForCurrentBundle else {
            throw CocoaError(.featureUnsupported)
        }

        let directory = agentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                "/usr/bin/open",
                "-g",
                Bundle.main.bundleURL.path
            ],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: agentURL, options: .atomic)
    }

    func uninstall() throws {
        guard isInstalled else {
            return
        }
        try FileManager.default.removeItem(at: agentURL)
    }

    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }
}

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let settings: SettingsStore
    private let scrollController: ScrollController
    private let launchAgentManager: LaunchAgentManager

    init(
        settings: SettingsStore,
        scrollController: ScrollController,
        launchAgentManager: LaunchAgentManager
    ) {
        self.settings = settings
        self.scrollController = scrollController
        self.launchAgentManager = launchAgentManager

        let viewController = SettingsViewController(
            settings: settings,
            scrollController: scrollController,
            launchAgentManager: launchAgentManager
        )

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 250)
        popover.contentViewController = viewController

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "arrow.up.and.down.circle",
                accessibilityDescription: "Smooth Scroll"
            )
            button.target = self
            button.action = #selector(togglePopover)
        }

        scrollController.addStatusObserver { [weak self] status in
            self?.updateStatusIcon(for: status)
        }
        updateStatusIcon(for: scrollController.status)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateStatusIcon(for status: ScrollStatus) {
        statusItem.button?.contentTintColor = switch status {
        case .running:
            .controlAccentColor
        case .disabled:
            .secondaryLabelColor
        case .permissionNeeded, .eventTapFailed:
            .systemOrange
        }
    }
}

@MainActor
final class SettingsViewController: NSViewController {
    private let settings: SettingsStore
    private let scrollController: ScrollController
    private let launchAgentManager: LaunchAgentManager

    private let statusLabel = NSTextField(labelWithString: "")
    private let enabledButton = NSButton()
    private let launchAtLoginButton = NSButton()
    private let strengthSlider = NSSlider()
    private let smoothnessSlider = NSSlider()
    private let strengthValueLabel = NSTextField(labelWithString: "")
    private let smoothnessValueLabel = NSTextField(labelWithString: "")

    init(
        settings: SettingsStore,
        scrollController: ScrollController,
        launchAgentManager: LaunchAgentManager
    ) {
        self.settings = settings
        self.scrollController = scrollController
        self.launchAgentManager = launchAgentManager
        super.init(nibName: nil, bundle: nil)
        self.scrollController.addStatusObserver { [weak self] _ in
            self?.refresh()
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 250))

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setHuggingPriority(.required, for: .vertical)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -18)
        ])

        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.lineBreakMode = .byTruncatingTail
        stack.addArrangedSubview(statusLabel)

        enabledButton.setButtonType(.switch)
        enabledButton.title = "Enabled"
        enabledButton.target = self
        enabledButton.action = #selector(enabledChanged)
        stack.addArrangedSubview(enabledButton)

        stack.addArrangedSubview(sliderRow(
            title: "Strength",
            slider: strengthSlider,
            valueLabel: strengthValueLabel,
            minValue: 24,
            maxValue: 180,
            action: #selector(strengthChanged)
        ))

        stack.addArrangedSubview(sliderRow(
            title: "Smoothness",
            slider: smoothnessSlider,
            valueLabel: smoothnessValueLabel,
            minValue: 0.06,
            maxValue: 0.50,
            action: #selector(smoothnessChanged)
        ))

        launchAtLoginButton.setButtonType(.switch)
        launchAtLoginButton.title = "Launch at Login"
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)
        stack.addArrangedSubview(launchAtLoginButton)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let privacyButton = NSButton(
            title: "Privacy Settings",
            target: self,
            action: #selector(openPrivacySettings)
        )
        let resetButton = NSButton(
            title: "Reset",
            target: self,
            action: #selector(resetScrolling)
        )
        let quitButton = NSButton(
            title: "Quit",
            target: self,
            action: #selector(quit)
        )

        buttonRow.addArrangedSubview(privacyButton)
        buttonRow.addArrangedSubview(resetButton)
        buttonRow.addArrangedSubview(quitButton)
        stack.addArrangedSubview(buttonRow)
        buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        refresh()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    private func sliderRow(
        title: String,
        slider: NSSlider,
        valueLabel: NSTextField,
        minValue: Double,
        maxValue: Double,
        action: Selector
    ) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 4
        container.alignment = .leading

        let labelRow = NSStackView()
        labelRow.orientation = .horizontal
        labelRow.alignment = .centerY
        labelRow.spacing = 8

        let titleLabel = NSTextField(labelWithString: title)
        valueLabel.alignment = .right
        valueLabel.textColor = .secondaryLabelColor

        labelRow.addArrangedSubview(titleLabel)
        labelRow.addArrangedSubview(valueLabel)
        labelRow.widthAnchor.constraint(equalToConstant: 264).isActive = true
        valueLabel.widthAnchor.constraint(equalToConstant: 72).isActive = true

        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.target = self
        slider.action = action
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 264).isActive = true

        container.addArrangedSubview(labelRow)
        container.addArrangedSubview(slider)
        return container
    }

    private func refresh() {
        statusLabel.stringValue = "Smooth Scroll: \(scrollController.status.title)"
        enabledButton.state = settings.enabled ? .on : .off
        launchAtLoginButton.state = settings.launchAtLogin ? .on : .off
        launchAtLoginButton.isEnabled = launchAgentManager.canInstallForCurrentBundle

        strengthSlider.doubleValue = settings.pixelsPerWheelStep
        smoothnessSlider.doubleValue = settings.timeConstant

        strengthValueLabel.stringValue = "\(Int(settings.pixelsPerWheelStep.rounded())) px"
        smoothnessValueLabel.stringValue = "\(Int((settings.timeConstant * 1000).rounded())) ms"
    }

    @objc private func enabledChanged() {
        settings.enabled = enabledButton.state == .on
        scrollController.applySettings()
        refresh()
    }

    @objc private func strengthChanged() {
        settings.pixelsPerWheelStep = strengthSlider.doubleValue
        scrollController.applySettings()
        refresh()
    }

    @objc private func smoothnessChanged() {
        settings.timeConstant = smoothnessSlider.doubleValue
        scrollController.applySettings()
        refresh()
    }

    @objc private func launchAtLoginChanged() {
        settings.launchAtLogin = launchAtLoginButton.state == .on
        do {
            if settings.launchAtLogin {
                try launchAgentManager.installForCurrentBundle()
                settings.launchAgentConfigured = true
            } else {
                try launchAgentManager.uninstall()
                settings.launchAgentConfigured = false
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        refresh()
    }

    @objc private func openPrivacySettings() {
        scrollController.requestAccessibilityPermission()
        let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        let inputMonitoring = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        let urlStrings = scrollController.status == .eventTapFailed
            ? [inputMonitoring, accessibility]
            : [accessibility, inputMonitoring]
        for urlString in urlStrings {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                break
            }
        }
    }

    @objc private func resetScrolling() {
        settings.resetScrolling()
        scrollController.applySettings()
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let launchAgentManager = LaunchAgentManager()
    private lazy var scrollController = ScrollController(settings: settings)
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        terminateDuplicateInstanceIfNeeded()

        settings.onChange = { [weak self] in
            self?.scrollController.applySettings()
        }

        configureLaunchAtLoginIfNeeded()

        statusController = StatusBarController(
            settings: settings,
            scrollController: scrollController,
            launchAgentManager: launchAgentManager
        )
        scrollController.requestAccessibilityPermission()
        scrollController.applySettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scrollController.stop()
    }

    private func configureLaunchAtLoginIfNeeded() {
        guard settings.launchAtLogin else {
            return
        }
        let needsInstall = !settings.launchAgentConfigured ||
            !launchAgentManager.isInstalled ||
            !launchAgentManager.pointsAtCurrentBundle
        guard needsInstall else {
            return
        }
        do {
            try launchAgentManager.installForCurrentBundle()
            settings.launchAgentConfigured = true
        } catch {
            settings.launchAgentConfigured = false
        }
    }

    private func terminateDuplicateInstanceIfNeeded() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let duplicate = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .contains { $0.processIdentifier != getpid() }

        if duplicate {
            NSApp.terminate(nil)
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
