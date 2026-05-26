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
    private enum ScrollStreamState {
        case idle
        case gesture
        case momentum
    }

    private let settings: SettingsStore
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var displayLink: DisplayLinkDriver?
    private var permissionRetryTimer: DispatchSourceTimer?
    private var lastInputTime: TimeInterval?
    private var streamState = ScrollStreamState.idle
    private var engine = ScrollPhysicsEngine()
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private let eventSynthesizer = TrackpadScrollEventSynthesizer()
    private let gestureQuietTime: TimeInterval = 0.11

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
        stopDisplayLink(finishingStream: true)
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

        if shouldPassThrough(event: event) {
            stopDisplayLink(finishingStream: true)
            engine.reset()
            return Unmanaged.passUnretained(event)
        }

        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        if isContinuous {
            return Unmanaged.passUnretained(event)
        }

        var vertical = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        var horizontal = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        guard vertical != 0 || horizontal != 0 else {
            return Unmanaged.passUnretained(event)
        }

        if settings.reverseVertical {
            vertical *= -1
        }
        if settings.reverseHorizontal {
            horizontal *= -1
        }

        if settings.precisionModifier.matches(event.flags) {
            vertical *= 0.35
            horizontal *= 0.35
        } else if settings.boostModifier.matches(event.flags) {
            vertical *= 1.75
            horizontal *= 1.75
        }

        engine.addWheelDelta(
            horizontalLines: horizontal,
            verticalLines: vertical
        )
        lastInputTime = ProcessInfo.processInfo.systemUptime
        if streamState == .momentum {
            finishMomentum()
        }
        startDisplayLinkIfNeeded()
        return nil
    }

    private func shouldPassThrough(event: CGEvent) -> Bool {
        if settings.bypassModifier.matches(event.flags) {
            return true
        }
        guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return settings.isExcluded(bundleIdentifier: bundleIdentifier)
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else {
            return
        }

        let displayLink = DisplayLinkDriver { [weak self] _, deltaTime in
            self?.tick(deltaTime: deltaTime)
        }
        displayLink?.start()
        self.displayLink = displayLink
    }

    private func tick(deltaTime: TimeInterval) {
        let now = ProcessInfo.processInfo.systemUptime
        let frame = engine.nextFrame(deltaTime: deltaTime)

        if frame.hasPixels {
            post(frame: frame, at: now)
        }

        if !engine.isActive {
            finishActiveStream()
            stopDisplayLink(finishingStream: false)
        }
    }

    private func post(frame: ScrollFrame, at now: TimeInterval) {
        let inputIsRecent = lastInputTime.map { now - $0 <= gestureQuietTime } ?? false

        switch streamState {
        case .idle:
            eventSynthesizer.resetLineAccumulator()
            streamState = .gesture
            eventSynthesizer.postScroll(
                deltaX: frame.pixelsX,
                deltaY: frame.pixelsY,
                scrollPhase: .began,
                momentumPhase: .none,
                syntheticMarker: Self.syntheticEventMarker,
                source: eventSource
            )
        case .gesture where inputIsRecent:
            eventSynthesizer.postScroll(
                deltaX: frame.pixelsX,
                deltaY: frame.pixelsY,
                scrollPhase: .changed,
                momentumPhase: .none,
                syntheticMarker: Self.syntheticEventMarker,
                source: eventSource
            )
        case .gesture:
            finishGesture()
            streamState = .momentum
            eventSynthesizer.postScroll(
                deltaX: frame.pixelsX,
                deltaY: frame.pixelsY,
                scrollPhase: .none,
                momentumPhase: .began,
                syntheticMarker: Self.syntheticEventMarker,
                source: eventSource
            )
        case .momentum:
            eventSynthesizer.postScroll(
                deltaX: frame.pixelsX,
                deltaY: frame.pixelsY,
                scrollPhase: .none,
                momentumPhase: .changed,
                syntheticMarker: Self.syntheticEventMarker,
                source: eventSource
            )
        }
    }

    private func finishActiveStream() {
        switch streamState {
        case .idle:
            break
        case .gesture:
            finishGesture()
        case .momentum:
            finishMomentum()
        }
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

private func openPrivacySettingsURL(for status: ScrollStatus) {
    let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    let inputMonitoring = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    let urlStrings = status == .eventTapFailed
        ? [inputMonitoring, accessibility]
        : [accessibility, inputMonitoring]
    for urlString in urlStrings {
        if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
            break
        }
    }
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
        guard let executablePath = Bundle.main.executablePath else {
            return false
        }
        return installedProgramArguments == [executablePath, "--background"]
    }

    var installedBundlePath: String? {
        installedProgramArguments.first { $0.hasSuffix(".app") }
    }

    private var installedProgramArguments: [String] {
        guard
            let data = try? Data(contentsOf: agentURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dictionary = plist as? [String: Any],
            let arguments = dictionary["ProgramArguments"] as? [String]
        else {
            return []
        }
        return arguments
    }

    func installForCurrentBundle() throws {
        guard canInstallForCurrentBundle else {
            throw CocoaError(.featureUnsupported)
        }
        guard let executablePath = Bundle.main.executablePath else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = agentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                executablePath,
                "--background"
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
    private let settings: SettingsStore
    private let scrollController: ScrollController
    private let launchAgentManager: LaunchAgentManager
    private let applicationMonitor: ApplicationMonitor
    private let settingsWindowController: SettingsWindowController
    private var settingsObserver: Any?

    init(
        settings: SettingsStore,
        scrollController: ScrollController,
        launchAgentManager: LaunchAgentManager,
        applicationMonitor: ApplicationMonitor
    ) {
        self.settings = settings
        self.scrollController = scrollController
        self.launchAgentManager = launchAgentManager
        self.applicationMonitor = applicationMonitor

        settingsWindowController = SettingsWindowController(
            settings: settings,
            scrollController: scrollController,
            launchAgentManager: launchAgentManager,
            applicationMonitor: applicationMonitor
        )

        if let button = statusItem.button {
            button.image = AppIcon.statusImage()
            button.target = self
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        scrollController.addStatusObserver { [weak self] status in
            self?.updateStatusIcon(for: status)
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification,
            object: settings,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatusItem()
            }
        }
        updateStatusIcon(for: scrollController.status)
    }

    @objc private func handleStatusItemClick() {
        guard let button = statusItem.button else {
            return
        }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuickMenu(relativeTo: button)
        } else {
            showSettings()
        }
    }

    private func updateStatusIcon(for status: ScrollStatus) {
        refreshStatusItem()
        statusItem.button?.toolTip = "Mouse++: \(status.title)"
    }

    private func refreshStatusItem() {
        statusItem.isVisible = settings.showInMenuBar
        statusItem.button?.image = AppIcon.statusImage()
        statusItem.button?.contentTintColor = .white
    }

    private func showQuickMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: settings.enabled ? "Disable Mouse++" : "Enable Mouse++",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = settings.enabled ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: "Update Mouse++", action: #selector(runUpdater), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let accessibilityItem = NSMenuItem(
            title: "Accessibility Settings...",
            action: #selector(openPrivacySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mouse++", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc func showSettings() {
        settingsWindowController.show()
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        scrollController.applySettings()
    }

    @objc private func openPrivacySettings() {
        scrollController.requestAccessibilityPermission()
        openPrivacySettingsURL(for: scrollController.status)
    }

    @objc private func runUpdater() {
        do {
            try AppUpdater.start()
        } catch {
            showAlert(
                title: "Update Failed",
                message: [error.localizedDescription, (error as? LocalizedError)?.recoverySuggestion]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            )
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private var hasCenteredWindow = false

    init(
        settings: SettingsStore,
        scrollController: ScrollController,
        launchAgentManager: LaunchAgentManager,
        applicationMonitor: ApplicationMonitor
    ) {
        let viewController = SettingsViewController(
            settings: settings,
            scrollController: scrollController,
            launchAgentManager: launchAgentManager,
            applicationMonitor: applicationMonitor
        )
        let window = NSWindow(contentViewController: viewController)
        window.title = "Mouse++"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 544, height: 520))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        if !hasCenteredWindow {
            window?.center()
            hasCenteredWindow = true
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum AppIcon {
    static func statusImage() -> NSImage {
        if let image = bundledImage(size: NSSize(width: 18, height: 18)) {
            return image
        }
        return fallbackStatusImage()
    }

    static func largeImage() -> NSImage {
        if let image = bundledImage(size: NSSize(width: 64, height: 64)) {
            return image
        }
        return fallbackLargeImage()
    }

    private static func bundledImage(size: NSSize) -> NSImage? {
        let url = Bundle.main.url(forResource: "AppIcon", withExtension: "svg") ??
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        guard
            let url,
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.size = size
        image.isTemplate = false
        return image
    }

    private static func fallbackStatusImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.white.setStroke()

        let body = NSBezierPath(roundedRect: NSRect(x: 5, y: 2.5, width: 8, height: 13), xRadius: 4, yRadius: 4)
        body.lineWidth = 1.9
        body.stroke()

        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 9, y: 15.2))
        divider.line(to: NSPoint(x: 9, y: 11.2))
        divider.lineWidth = 1.5
        divider.stroke()

        let wheel = NSBezierPath()
        wheel.move(to: NSPoint(x: 9, y: 10.1))
        wheel.line(to: NSPoint(x: 9, y: 8.2))
        wheel.lineWidth = 1.8
        wheel.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func fallbackLargeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 64, height: 64))
        image.lockFocus()

        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 56, height: 56), xRadius: 14, yRadius: 14).fill()

        NSColor.white.setStroke()
        let body = NSBezierPath(roundedRect: NSRect(x: 23, y: 13, width: 18, height: 38), xRadius: 9, yRadius: 9)
        body.lineWidth = 3.5
        body.stroke()

        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 32, y: 51))
        divider.line(to: NSPoint(x: 32, y: 40))
        divider.lineWidth = 2.8
        divider.stroke()

        let wheel = NSBezierPath()
        wheel.move(to: NSPoint(x: 32, y: 37))
        wheel.line(to: NSPoint(x: 32, y: 31))
        wheel.lineWidth = 3.2
        wheel.stroke()

        image.unlockFocus()
        return image
    }
}

private enum AppUpdater {
    static func start() throws {
        let updaterURL = try updaterScriptURL()
        let logHandle = try updateLogHandle()

        var environment = ProcessInfo.processInfo.environment
        environment["MOUSE_PLUS_PLUS_UPDATE_FROM_APP"] = "1"
        if let installDirectory = installedDirectoryPath() {
            environment["SMOOTH_SCROLL_INSTALL_DIR"] = installDirectory
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        process.arguments = ["/bin/zsh", updaterURL.path]
        process.currentDirectoryURL = updaterURL.deletingLastPathComponent()
        process.environment = environment
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()
    }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Mouse++", isDirectory: true)
            .appendingPathComponent("update.log")
    }

    private static func updaterScriptURL() throws -> URL {
        let candidates = [
            ProcessInfo.processInfo.environment["MOUSE_PLUS_PLUS_UPDATER"].map(URL.init(fileURLWithPath:)),
            sourceRootPath().map { URL(fileURLWithPath: $0).appendingPathComponent("install.sh") },
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads", isDirectory: true)
                .appendingPathComponent("macmouse", isDirectory: true)
                .appendingPathComponent("install.sh")
        ].compactMap { $0 }

        if let updaterURL = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return updaterURL
        }

        throw UpdaterError.notFound
    }

    private static func updateLogHandle() throws -> FileHandle {
        let directoryURL = logURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        return handle
    }

    private static func sourceRootPath() -> String? {
        bundledPath(named: "SourceRoot")
    }

    private static func installedDirectoryPath() -> String? {
        bundledPath(named: "InstallDirectory")
    }

    private static func bundledPath(named name: String) -> String? {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "path"),
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }
        let path = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    enum UpdaterError: LocalizedError {
        case notFound

        var errorDescription: String? {
            switch self {
            case .notFound:
                "Mouse++ could not find its update script."
            }
        }

        var recoverySuggestion: String? {
            "Run install.sh once from the source folder, then use Update Mouse++ from the app."
        }
    }
}

@MainActor
final class NumberInputRow: NSStackView, NSTextFieldDelegate {
    private let minValue: Double
    private let maxValue: Double
    private let decimals: Int
    private let textField = NSTextField()
    private let stepper = NSStepper()
    private var isUpdating = false

    var onValueChange: ((Double) -> Void)?

    init(title: String, minValue: Double, maxValue: Double, step: Double, decimals: Int, suffix: String) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.decimals = decimals
        super.init(frame: .zero)

        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 400).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.widthAnchor.constraint(equalToConstant: 138).isActive = true

        textField.alignment = .right
        textField.controlSize = .regular
        textField.target = self
        textField.action = #selector(textFieldChanged)
        textField.delegate = self
        textField.widthAnchor.constraint(equalToConstant: 74).isActive = true

        let suffixLabel = NSTextField(labelWithString: suffix)
        suffixLabel.textColor = .secondaryLabelColor
        suffixLabel.widthAnchor.constraint(equalToConstant: 34).isActive = true

        stepper.minValue = minValue
        stepper.maxValue = maxValue
        stepper.increment = step
        stepper.controlSize = .small
        stepper.target = self
        stepper.action = #selector(stepperChanged)

        let inputGroup = NSStackView()
        inputGroup.orientation = .horizontal
        inputGroup.alignment = .centerY
        inputGroup.spacing = 2
        inputGroup.addArrangedSubview(textField)
        inputGroup.addArrangedSubview(stepper)

        addArrangedSubview(titleLabel)
        addArrangedSubview(inputGroup)
        addArrangedSubview(suffixLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: Double) {
        let value = value.clamped(to: minValue ... maxValue)
        isUpdating = true
        stepper.doubleValue = value
        textField.stringValue = formatted(value)
        isUpdating = false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitTextFieldValue()
    }

    @objc private func textFieldChanged() {
        commitTextFieldValue()
    }

    @objc private func stepperChanged() {
        apply(stepper.doubleValue)
    }

    private func commitTextFieldValue() {
        guard let value = Double(textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            setValue(stepper.doubleValue)
            return
        }
        apply(value)
    }

    private func apply(_ rawValue: Double) {
        let value = rawValue.clamped(to: minValue ... maxValue)
        setValue(value)
        guard !isUpdating else {
            return
        }
        onValueChange?(value)
    }

    private func formatted(_ value: Double) -> String {
        if decimals == 0 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.\(decimals)f", value)
    }
}

@MainActor
class ClickableView: NSView {
    var onClick: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) != nil ? self : nil
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            onClick?()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

@MainActor
final class TabBarItem: ClickableView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var isSelected = false

    init(title: String, symbolName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8

        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 19, weight: .regular))
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown

        label.stringValue = title
        label.font = .systemFont(ofSize: 11.5, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .center

        let stack = NSStackView(views: [iconView, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalTo: stack.widthAnchor, constant: 22),
            heightAnchor.constraint(equalTo: stack.heightAnchor, constant: 12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        applyStyle()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyStyle()
    }

    private func applyStyle() {
        let color: NSColor = isSelected ? .controlAccentColor : .secondaryLabelColor
        iconView.contentTintColor = color
        label.textColor = color
        if isSelected {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            }
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

@MainActor
final class LinkButton: ClickableView {
    init(title: String, symbolName: String, onClick: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        iconView.contentTintColor = .controlAccentColor

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .controlAccentColor

        let stack = NSStackView(views: [iconView, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor)
        ])

        self.onClick = onClick
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
final class SettingsViewController: NSViewController {
    private enum SettingsTab: Int, CaseIterable {
        case general
        case scrolling
        case apps
        case about

        var title: String {
            switch self {
            case .general:
                "General"
            case .scrolling:
                "Scrolling"
            case .apps:
                "Apps"
            case .about:
                "About"
            }
        }

        var symbolName: String {
            switch self {
            case .general:
                "gearshape"
            case .scrolling:
                "arrow.up.and.down"
            case .apps:
                "app.badge"
            case .about:
                "info.circle"
            }
        }

        var contentSize: NSSize {
            switch self {
            case .general:
                NSSize(width: 544, height: 230)
            case .scrolling:
                NSSize(width: 544, height: 520)
            case .apps:
                NSSize(width: 544, height: 300)
            case .about:
                NSSize(width: 544, height: 255)
            }
        }
    }

    private let settings: SettingsStore
    private let scrollController: ScrollController
    private let launchAgentManager: LaunchAgentManager
    private let applicationMonitor: ApplicationMonitor
    private let contentWidth: CGFloat = 420
    private let contentContainer = NSView()
    private var tabButtons: [SettingsTab: TabBarItem] = [:]
    private var selectedTab: SettingsTab = .scrolling
    private var accessibilityRows: [NSView] = []

    private let launchAtLoginButton = NSSwitch()
    private let presetPopup = NSPopUpButton()
    private let bypassPopup = NSPopUpButton()
    private let precisionPopup = NSPopUpButton()
    private let boostPopup = NSPopUpButton()
    private let excludedAppsPopup = NSPopUpButton()
    private let currentAppLabel = NSTextField(labelWithString: "")
    private let versionLabel = NSTextField(labelWithString: "")
    private let reverseVerticalButton = NSButton()
    private let reverseHorizontalButton = NSButton()
    private let showInMenuBarButton = NSSwitch()
    private var strengthRow: NumberInputRow!
    private var smoothnessRow: NumberInputRow!
    private var verticalRow: NumberInputRow!
    private var horizontalRow: NumberInputRow!
    private var accelerationRow: NumberInputRow!

    init(
        settings: SettingsStore,
        scrollController: ScrollController,
        launchAgentManager: LaunchAgentManager,
        applicationMonitor: ApplicationMonitor
    ) {
        self.settings = settings
        self.scrollController = scrollController
        self.launchAgentManager = launchAgentManager
        self.applicationMonitor = applicationMonitor
        super.init(nibName: nil, bundle: nil)
        self.scrollController.addStatusObserver { [weak self] _ in
            self?.refresh()
        }
        self.applicationMonitor.onChange = { [weak self] in
            self?.refresh()
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: SettingsTab.scrolling.contentSize))

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        let tabBar = NSStackView()
        tabBar.orientation = .horizontal
        tabBar.alignment = .centerY
        tabBar.spacing = 2
        tabBar.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        for tab in SettingsTab.allCases {
            let item = TabBarItem(title: tab.title, symbolName: tab.symbolName)
            item.onClick = { [weak self] in self?.selectTab(tab) }
            tabButtons[tab] = item
            tabBar.addArrangedSubview(item)
        }
        root.addArrangedSubview(tabBar)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(separator)

        contentContainer.wantsLayer = true
        contentContainer.layer?.masksToBounds = true
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(contentContainer)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            separator.widthAnchor.constraint(equalTo: root.widthAnchor),
            contentContainer.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])

        selectTab(.scrolling)
        refresh()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    private func selectTab(_ tab: SettingsTab) {
        guard selectedTab != tab || contentContainer.subviews.isEmpty else {
            return
        }
        let isInitial = contentContainer.subviews.isEmpty
        selectedTab = tab
        for (candidate, item) in tabButtons {
            item.setSelected(candidate == tab)
        }

        installContent(for: tab)
        resizeWindow(to: tab.contentSize, animated: !isInitial && view.window != nil)
    }

    private func installContent(for tab: SettingsTab) {
        accessibilityRows.removeAll()
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        let content: NSView = switch tab {
        case .general:
            generalView()
        case .scrolling:
            scrollingView()
        case .apps:
            appsView()
        case .about:
            aboutView()
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentContainer.topAnchor)
        ])
        refresh()
        contentContainer.layoutSubtreeIfNeeded()
    }

    private func resizeWindow(
        to contentSize: NSSize,
        animated: Bool
    ) {
        guard let window = view.window else {
            view.setFrameSize(contentSize)
            return
        }
        let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        var targetFrame = window.frame
        let topY = targetFrame.maxY
        targetFrame.size = targetFrameSize
        targetFrame.origin.y = topY - targetFrameSize.height

        guard animated else {
            window.setFrame(targetFrame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            window.animator().setFrame(targetFrame, display: true)
        }
    }

    private func contentStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func wrapped(_ stack: NSStackView) -> NSView {
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 52),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -52),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        return container
    }

    private func generalView() -> NSView {
        let stack = contentStack()

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)
        stack.addArrangedSubview(toggleRow(title: "Launch at Login", control: launchAtLoginButton))

        showInMenuBarButton.target = self
        showInMenuBarButton.action = #selector(showInMenuBarChanged)
        stack.addArrangedSubview(toggleRow(title: "Show in Menu Bar", control: showInMenuBarButton))

        stack.addArrangedSubview(accessibilityRow())
        currentAppLabel.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(sectionRow(title: "Current App", valueLabel: currentAppLabel, trailing: nil))

        return wrapped(stack)
    }

    private func toggleRow(title: String, control: NSSwitch) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(label)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(control)
        return row
    }

    private func scrollingView() -> NSView {
        let stack = contentStack()

        stack.addArrangedSubview(presetRow())

        smoothnessRow = numberRow(
            title: "Smoothness",
            minValue: 60,
            maxValue: 500,
            step: 10,
            decimals: 0,
            suffix: "ms"
        ) { [weak self] value in
            self?.settings.timeConstant = value / 1000.0
            self?.scrollController.applySettings()
            self?.refresh()
        }
        stack.addArrangedSubview(smoothnessRow)

        strengthRow = numberRow(
            title: "Strength",
            minValue: 24,
            maxValue: 180,
            step: 1,
            decimals: 0,
            suffix: "px"
        ) { [weak self] value in
            self?.settings.pixelsPerWheelStep = value
            self?.scrollController.applySettings()
            self?.refresh()
        }
        stack.addArrangedSubview(strengthRow)

        verticalRow = numberRow(
            title: "Vertical",
            minValue: 25,
            maxValue: 200,
            step: 5,
            decimals: 0,
            suffix: "%"
        ) { [weak self] value in
            self?.settings.verticalMultiplier = value / 100.0
            self?.scrollController.applySettings()
            self?.refresh()
        }
        stack.addArrangedSubview(verticalRow)

        horizontalRow = numberRow(
            title: "Horizontal",
            minValue: 25,
            maxValue: 200,
            step: 5,
            decimals: 0,
            suffix: "%"
        ) { [weak self] value in
            self?.settings.horizontalMultiplier = value / 100.0
            self?.scrollController.applySettings()
            self?.refresh()
        }
        stack.addArrangedSubview(horizontalRow)

        accelerationRow = numberRow(
            title: "Acceleration",
            minValue: 0,
            maxValue: 200,
            step: 5,
            decimals: 0,
            suffix: "%"
        ) { [weak self] value in
            self?.settings.acceleration = value / 100.0
            self?.scrollController.applySettings()
            self?.refresh()
        }
        stack.addArrangedSubview(accelerationRow)

        let reverseRow = NSStackView()
        reverseRow.orientation = .horizontal
        reverseRow.spacing = 28
        reverseRow.alignment = .centerY
        reverseVerticalButton.setButtonType(.switch)
        reverseVerticalButton.title = "Reverse Vertical"
        reverseVerticalButton.target = self
        reverseVerticalButton.action = #selector(reverseVerticalChanged)
        reverseHorizontalButton.setButtonType(.switch)
        reverseHorizontalButton.title = "Reverse Horizontal"
        reverseHorizontalButton.target = self
        reverseHorizontalButton.action = #selector(reverseHorizontalChanged)
        reverseRow.addArrangedSubview(reverseVerticalButton)
        reverseRow.addArrangedSubview(reverseHorizontalButton)
        stack.addArrangedSubview(reverseRow)

        configureBypassPopup()
        stack.addArrangedSubview(popupRow(title: "Bypass", popup: bypassPopup))
        configureModifierPopup(precisionPopup, action: #selector(precisionModifierChanged))
        stack.addArrangedSubview(popupRow(title: "Precision", popup: precisionPopup))
        configureModifierPopup(boostPopup, action: #selector(boostModifierChanged))
        stack.addArrangedSubview(popupRow(title: "Swift", popup: boostPopup))

        stack.addArrangedSubview(actionButton("Reset Scrolling", action: #selector(resetScrolling)))

        return wrapped(stack)
    }

    private func appsView() -> NSView {
        let stack = contentStack()

        stack.addArrangedSubview(sectionRow(title: "Current App", valueLabel: currentAppLabel, trailing: NSButton(
            title: "Exclude",
            target: self,
            action: #selector(addCurrentAppExclusion)
        )))

        stack.addArrangedSubview(commandRow(buttons: [
            NSButton(title: "Remove", target: self, action: #selector(removeSelectedAppExclusion))
        ]))

        excludedAppsPopup.translatesAutoresizingMaskIntoConstraints = false
        excludedAppsPopup.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        stack.addArrangedSubview(labelledControl(title: "Excluded Apps", control: excludedAppsPopup))

        return wrapped(stack)
    }

    private func advancedView() -> NSView {
        let stack = contentStack()

        verticalRow = numberRow(
            title: "Vertical",
            minValue: 25,
            maxValue: 200,
            step: 5,
            decimals: 0,
            suffix: "%"
        ) { [weak self] value in
            self?.settings.verticalMultiplier = value / 100.0
            self?.scrollController.applySettings()
            self?.refresh()
        }
        stack.addArrangedSubview(verticalRow)

        horizontalRow = numberRow(
            title: "Horizontal",
            minValue: 25,
            maxValue: 200,
            step: 5,
            decimals: 0,
            suffix: "%"
        ) { [weak self] value in
            self?.settings.horizontalMultiplier = value / 100.0
            self?.scrollController.applySettings()
            self?.refresh()
        }
        stack.addArrangedSubview(horizontalRow)

        accelerationRow = numberRow(
            title: "Acceleration",
            minValue: 0,
            maxValue: 200,
            step: 5,
            decimals: 0,
            suffix: "%"
        ) { [weak self] value in
            self?.settings.acceleration = value / 100.0
            self?.scrollController.applySettings()
            self?.refresh()
        }
        stack.addArrangedSubview(accelerationRow)

        reverseVerticalButton.setButtonType(.switch)
        reverseVerticalButton.title = "Reverse Vertical"
        reverseVerticalButton.target = self
        reverseVerticalButton.action = #selector(reverseVerticalChanged)
        stack.addArrangedSubview(reverseVerticalButton)

        reverseHorizontalButton.setButtonType(.switch)
        reverseHorizontalButton.title = "Reverse Horizontal"
        reverseHorizontalButton.target = self
        reverseHorizontalButton.action = #selector(reverseHorizontalChanged)
        stack.addArrangedSubview(reverseHorizontalButton)

        configureBypassPopup()
        stack.addArrangedSubview(labelledControl(title: "Bypass Key", control: bypassPopup))

        configureModifierPopup(precisionPopup, action: #selector(precisionModifierChanged))
        stack.addArrangedSubview(labelledControl(title: "Precision Key", control: precisionPopup))

        configureModifierPopup(boostPopup, action: #selector(boostModifierChanged))
        stack.addArrangedSubview(labelledControl(title: "Boost Key", control: boostPopup))

        return wrapped(stack)
    }

    private func aboutView() -> NSView {
        let stack = contentStack()
        stack.alignment = .centerX
        stack.spacing = 16

        let header = NSStackView()
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 5

        let imageView = NSImageView(image: AppIcon.largeImage())
        imageView.widthAnchor.constraint(equalToConstant: 52).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let title = NSTextField(labelWithString: "Mouse++")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        header.addArrangedSubview(imageView)
        header.addArrangedSubview(title)
        header.addArrangedSubview(versionLabel)
        stack.addArrangedSubview(header)

        stack.addArrangedSubview(linkGrid([
            linkButton(title: "Update Mouse++", symbolName: "arrow.down.circle") { [weak self] in
                self?.runUpdater()
            },
            linkButton(title: "GitHub", symbolName: "chevron.left.forwardslash.chevron.right") { [weak self] in
                self?.openGitHub()
            }
        ]))

        return wrapped(stack)
    }

    private func presetRow() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 8
        container.alignment = .centerY
        container.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        let titleLabel = NSTextField(labelWithString: "Preset")
        titleLabel.widthAnchor.constraint(equalToConstant: 138).isActive = true

        configurePresetPopup()
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(presetPopup)
        return container
    }

    private func configurePresetPopup() {
        guard presetPopup.numberOfItems == 0 else {
            return
        }
        presetPopup.translatesAutoresizingMaskIntoConstraints = false
        presetPopup.widthAnchor.constraint(equalToConstant: 166).isActive = true
        presetPopup.addItem(withTitle: "Custom")
        presetPopup.lastItem?.representedObject = -1
        for (index, preset) in ScrollPreset.all.enumerated() {
            presetPopup.addItem(withTitle: preset.title)
            presetPopup.lastItem?.representedObject = index
        }
        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
    }

    private func accessibilityRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        icon.contentTintColor = .systemOrange
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let title = NSTextField(labelWithString: "Accessibility access required")
        title.font = .systemFont(ofSize: 13, weight: .medium)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let button = NSButton(title: "Open Settings", target: self, action: #selector(openPrivacySettings))

        row.addArrangedSubview(icon)
        row.addArrangedSubview(title)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(button)
        accessibilityRows.append(row)
        return row
    }

    private func sectionRow(title: String, valueLabel: NSTextField, trailing: NSView?) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(valueLabel)
        if let trailing {
            row.addArrangedSubview(trailing)
        }
        return row
    }

    private func labelledControl(title: String, control: NSView) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 4
        container.alignment = .leading
        container.addArrangedSubview(NSTextField(labelWithString: title))
        container.addArrangedSubview(control)
        return container
    }

    private func popupRow(title: String, popup: NSPopUpButton) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.widthAnchor.constraint(equalToConstant: 138).isActive = true

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(popup)
        return row
    }

    private func commandRow(buttons: [NSButton]) -> NSView {
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        for button in buttons {
            buttonRow.addArrangedSubview(button)
        }
        return buttonRow
    }

    private func linkGrid(_ buttons: [NSView]) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 28
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        for button in buttons {
            button.widthAnchor.constraint(equalToConstant: 190).isActive = true
            row.addArrangedSubview(button)
        }
        return row
    }

    private func actionButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func linkButton(title: String, symbolName: String, onClick: @escaping () -> Void) -> LinkButton {
        LinkButton(title: title, symbolName: symbolName, onClick: onClick)
    }

    private func numberRow(
        title: String,
        minValue: Double,
        maxValue: Double,
        step: Double,
        decimals: Int,
        suffix: String,
        onChange: @escaping (Double) -> Void
    ) -> NumberInputRow {
        let row = NumberInputRow(
            title: title,
            minValue: minValue,
            maxValue: maxValue,
            step: step,
            decimals: decimals,
            suffix: suffix
        )
        row.onValueChange = onChange
        return row
    }

    private func configureBypassPopup() {
        configureModifierPopup(bypassPopup, action: #selector(bypassModifierChanged))
    }

    private func configureModifierPopup(_ popup: NSPopUpButton, action: Selector) {
        guard popup.numberOfItems == 0 else {
            return
        }
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 166).isActive = true
        for modifier in BypassModifier.allCases {
            popup.addItem(withTitle: modifier.title)
            popup.lastItem?.representedObject = modifier.rawValue
        }
        popup.target = self
        popup.action = action
    }

    private func refresh() {
        versionLabel.stringValue = "Version \(appVersion)"
        currentAppLabel.stringValue = currentTargetApplicationTitle()
        launchAtLoginButton.state = settings.launchAtLogin ? .on : .off
        launchAtLoginButton.isEnabled = launchAgentManager.canInstallForCurrentBundle
        showInMenuBarButton.state = settings.showInMenuBar ? .on : .off

        strengthRow?.setValue(settings.pixelsPerWheelStep)
        smoothnessRow?.setValue(settings.timeConstant * 1000.0)
        verticalRow?.setValue(settings.verticalMultiplier * 100.0)
        horizontalRow?.setValue(settings.horizontalMultiplier * 100.0)
        accelerationRow?.setValue(settings.acceleration * 100.0)

        let selectedPresetIndex = selectedPresetIndex()
        presetPopup.selectItem(withTitle: selectedPresetIndex >= 0 ? ScrollPreset.all[selectedPresetIndex].title : "Custom")
        bypassPopup.selectItem(withTitle: settings.bypassModifier.title)
        precisionPopup.selectItem(withTitle: settings.precisionModifier.title)
        boostPopup.selectItem(withTitle: settings.boostModifier.title)
        reverseVerticalButton.state = settings.reverseVertical ? .on : .off
        reverseHorizontalButton.state = settings.reverseHorizontal ? .on : .off
        refreshExcludedAppsPopup()
        refreshAccessibilityStatus()
    }

    private func selectedPresetIndex() -> Int {
        let currentPreset = ScrollPreset(
            title: "",
            pixelsPerWheelStep: settings.pixelsPerWheelStep,
            timeConstant: settings.timeConstant,
            acceleration: settings.acceleration
        )
        guard let index = ScrollPreset.all.firstIndex(where: { preset in
            abs(preset.pixelsPerWheelStep - currentPreset.pixelsPerWheelStep) < 0.5 &&
                abs(preset.timeConstant - currentPreset.timeConstant) < 0.001 &&
                abs(preset.acceleration - currentPreset.acceleration) < 0.001 &&
                abs(settings.verticalMultiplier - 1.0) < 0.001 &&
                abs(settings.horizontalMultiplier - 1.0) < 0.001
        }) else {
            return -1
        }
        return index
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func refreshAccessibilityStatus() {
        let isTrusted = AXIsProcessTrusted()
        for row in accessibilityRows {
            row.isHidden = isTrusted
        }
    }

    private func refreshExcludedAppsPopup() {
        let selectedBundleIdentifier = excludedAppsPopup.selectedItem?.representedObject as? String
        excludedAppsPopup.removeAllItems()
        let bundleIdentifiers = settings.excludedBundleIdentifiers
        guard !bundleIdentifiers.isEmpty else {
            excludedAppsPopup.addItem(withTitle: "No excluded apps")
            excludedAppsPopup.isEnabled = false
            return
        }
        excludedAppsPopup.isEnabled = true
        for bundleIdentifier in bundleIdentifiers {
            excludedAppsPopup.addItem(withTitle: appDisplayName(for: bundleIdentifier))
            excludedAppsPopup.lastItem?.representedObject = bundleIdentifier
        }
        if let selectedBundleIdentifier {
            excludedAppsPopup.selectItem(withTitle: appDisplayName(for: selectedBundleIdentifier))
        }
    }

    private func currentTargetApplicationTitle() -> String {
        guard let application = applicationMonitor.currentTargetApplication else {
            return "Unknown"
        }
        return application.localizedName ?? application.bundleIdentifier ?? "Unknown"
    }

    private func appDisplayName(for bundleIdentifier: String) -> String {
        let runningApp = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier
        }
        guard let name = runningApp?.localizedName else {
            return bundleIdentifier
        }
        return "\(name) (\(bundleIdentifier))"
    }

    @objc private func presetChanged() {
        guard
            let index = presetPopup.selectedItem?.representedObject as? Int,
            ScrollPreset.all.indices.contains(index)
        else {
            return
        }
        settings.applyPreset(ScrollPreset.all[index])
        scrollController.applySettings()
        refresh()
    }

    @objc private func bypassModifierChanged() {
        guard
            let rawValue = bypassPopup.selectedItem?.representedObject as? String,
            let modifier = BypassModifier(rawValue: rawValue)
        else {
            return
        }
        settings.bypassModifier = modifier
        refresh()
    }

    @objc private func precisionModifierChanged() {
        guard
            let rawValue = precisionPopup.selectedItem?.representedObject as? String,
            let modifier = BypassModifier(rawValue: rawValue)
        else {
            return
        }
        settings.precisionModifier = modifier
        refresh()
    }

    @objc private func boostModifierChanged() {
        guard
            let rawValue = boostPopup.selectedItem?.representedObject as? String,
            let modifier = BypassModifier(rawValue: rawValue)
        else {
            return
        }
        settings.boostModifier = modifier
        refresh()
    }

    @objc private func reverseVerticalChanged() {
        settings.reverseVertical = reverseVerticalButton.state == .on
        scrollController.applySettings()
        refresh()
    }

    @objc private func reverseHorizontalChanged() {
        settings.reverseHorizontal = reverseHorizontalButton.state == .on
        scrollController.applySettings()
        refresh()
    }

    @objc private func addCurrentAppExclusion() {
        guard let bundleIdentifier = applicationMonitor.currentTargetBundleIdentifier else {
            return
        }
        settings.addExcludedBundleIdentifier(bundleIdentifier)
        scrollController.applySettings()
        refresh()
    }

    @objc private func removeSelectedAppExclusion() {
        guard let bundleIdentifier = excludedAppsPopup.selectedItem?.representedObject as? String else {
            return
        }
        settings.removeExcludedBundleIdentifier(bundleIdentifier)
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

    @objc private func showInMenuBarChanged() {
        settings.showInMenuBar = showInMenuBarButton.state == .on
        refresh()
    }

    @objc private func openPrivacySettings() {
        scrollController.requestAccessibilityPermission()
        openPrivacySettingsURL(for: scrollController.status)
    }

    @objc private func openGitHub() {
        guard let url = URL(string: "https://github.com/5eanxlee/smooth-scroll") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func runUpdater() {
        do {
            try AppUpdater.start()
        } catch {
            showAlert(
                title: "Update Failed",
                message: [error.localizedDescription, (error as? LocalizedError)?.recoverySuggestion]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            )
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
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
    private let applicationMonitor = ApplicationMonitor()
    private lazy var scrollController = ScrollController(settings: settings)
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = AppIcon.largeImage()
        terminateDuplicateInstanceIfNeeded()

        settings.onChange = { [weak self] in
            self?.scrollController.applySettings()
        }

        configureLaunchAtLoginIfNeeded()

        statusController = StatusBarController(
            settings: settings,
            scrollController: scrollController,
            launchAgentManager: launchAgentManager,
            applicationMonitor: applicationMonitor
        )
        scrollController.requestAccessibilityPermission()
        scrollController.applySettings()
        if !CommandLine.arguments.contains("--background") {
            statusController?.showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        scrollController.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusController?.showSettings()
        return true
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
