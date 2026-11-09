import Flutter
import UIKit

/// Screen privacy for AppArmor: app switcher blur, cover while recording,
/// screenshot detection, and first-run detection for the Keychain.
public class AppArmorPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel

  private var hideInAppSwitcher = false
  private var blockScreenshots = false
  private var coverWhileRecording = false
  private var detectScreenshots = false
  private var secureScreen = false

  private var privacyCover: UIView?
  private var recordingCover: UIView?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    let center = NotificationCenter.default
    // Apps with and without UIScene: both sets of notifications, the cover
    // is only added once.
    center.addObserver(
      self, selector: #selector(willResignActive),
      name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(willResignActive),
      name: UIScene.willDeactivateNotification, object: nil)
    center.addObserver(
      self, selector: #selector(didBecomeActive),
      name: UIScene.didActivateNotification, object: nil)
    center.addObserver(
      self, selector: #selector(didTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    center.addObserver(
      self, selector: #selector(captureChanged),
      name: UIScreen.capturedDidChangeNotification, object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "app_armor", binaryMessenger: registrar.messenger())
    let instance = AppArmorPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      let args = call.arguments as? [String: Any] ?? [:]
      hideInAppSwitcher = args["hideInAppSwitcher"] as? Bool ?? false
      blockScreenshots = args["blockScreenshots"] as? Bool ?? false
      coverWhileRecording = args["coverWhileRecording"] as? Bool ?? false
      detectScreenshots = args["detectScreenshots"] as? Bool ?? false
      updateRecordingCover()
      result(nil)
    case "setSecureScreen":
      secureScreen = call.arguments as? Bool ?? false
      updateRecordingCover()
      result(nil)
    case "isScreenCaptured":
      result(UIScreen.main.isCaptured)
    case "consumeFirstRun":
      // UserDefaults is deleted with the app; the Keychain is not.
      let defaults = UserDefaults.standard
      let key = "app_armor.installed"
      let first = !defaults.bool(forKey: key)
      if first { defaults.set(true, forKey: key) }
      result(first)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: App switcher

  @objc private func willResignActive() {
    guard hideInAppSwitcher, privacyCover == nil, let window = keyWindow() else { return }
    privacyCover = addBlur(to: window)
  }

  @objc private func didBecomeActive() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }

  // MARK: Screenshots and recording

  @objc private func didTakeScreenshot() {
    if detectScreenshots { channel.invokeMethod("screenshotTaken", arguments: nil) }
  }

  @objc private func captureChanged() {
    let captured = UIScreen.main.isCaptured
    if detectScreenshots { channel.invokeMethod("captureChanged", arguments: captured) }
    updateRecordingCover()
  }

  /// iOS can't block screenshots, but it can hide the app while the screen
  /// is recorded, mirrored or cast.
  private func updateRecordingCover() {
    let wanted = coverWhileRecording || blockScreenshots || secureScreen
    if wanted && UIScreen.main.isCaptured {
      guard recordingCover == nil, let window = keyWindow() else { return }
      recordingCover = addBlur(to: window)
    } else {
      recordingCover?.removeFromSuperview()
      recordingCover = nil
    }
  }

  // MARK: Helpers

  private func addBlur(to window: UIWindow) -> UIView {
    let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    cover.frame = window.bounds
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(cover)
    return cover
  }

  private func keyWindow() -> UIWindow? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    return windows.first(where: { $0.isKeyWindow }) ?? windows.first
  }
}
