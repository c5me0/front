import Flutter
import UIKit
import PushKit
import CallKit
import AVFoundation
import UserNotifications
import WebRTC

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var calls: CameoSystemCalls?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self
    if let registrar = registrar(forPlugin: "CameoSystemCalls") {
      calls = CameoSystemCalls(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    calls?.setToken(deviceToken, platform: "apns")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                      withCompletionHandler completionHandler: @escaping () -> Void) {
    let data = response.notification.request.content.userInfo
    if let id = data["call_id"] as? String {
      calls?.emit(["type": "open_record", "id": id])
    } else { calls?.emit(["type": "refresh"]) }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    calls?.emit(["type": "refresh"])
    let kind = notification.request.content.userInfo["type"] as? String
    if calls?.hasCall == true && kind == "photo_shared" { completionHandler([]) }
    else { super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler) }
  }
}

private final class CameoSystemCalls: NSObject, PKPushRegistryDelegate, CXProviderDelegate {
  private let channel: FlutterMethodChannel
  private let provider: CXProvider
  private let controller = CXCallController()
  private var registry: PKPushRegistry?
  private var tokens: [String: String] = [:]
  private var queued: [[String: Any]] = []
  private var active: Set<UUID> = []
  private var outgoing: Set<UUID> = []
  private var answers: [UUID: CXAnswerCallAction] = [:]
  private var ready = false
  private var enabled = false
  var hasCall: Bool { !active.isEmpty }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "cameo/system_calls", binaryMessenger: messenger)
    let config = CXProviderConfiguration(localizedName: "Cameo")
    config.supportsVideo = false
    config.maximumCallGroups = 1
    config.maximumCallsPerCallGroup = 1
    config.supportedHandleTypes = [.generic]
    provider = CXProvider(configuration: config)
    super.init()
    provider.setDelegate(self, queue: .main)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    enabled = UserDefaults.standard.bool(forKey: "cameo.remoteCalls.enabled")
    if enabled {
      registry = PKPushRegistry(queue: .main)
      registry?.delegate = self
      registry?.desiredPushTypes = [.voIP]
    }
  }

  func emit(_ event: [String: Any]) {
    if ready { channel.invokeMethod("event", arguments: event) }
    else { queued.append(event) }
  }

  func setToken(_ data: Data, platform: String) {
    let token = data.map { String(format: "%02x", $0) }.joined()
    tokens[platform] = token
    emit(["type": "token", "platform": platform, "token": token])
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "configure" {
      enabled = args["enabled"] as? Bool ?? false
      UserDefaults.standard.set(enabled, forKey: "cameo.remoteCalls.enabled")
      ready = true
      if enabled {
        UIApplication.shared.registerForRemoteNotifications()
        if registry == nil { registry = PKPushRegistry(queue: .main); registry?.delegate = self }
        registry?.desiredPushTypes = [.voIP]
      } else {
        registry?.desiredPushTypes = []
        for id in active { end(id, failed: false) }
      }
      let events = queued; queued.removeAll()
      result(["tokens": tokens, "events": events]); return
    }
    if call.method == "tokens" { result(tokens); return }
    guard let raw = args["id"] as? String, let id = UUID(uuidString: raw) else { result(nil); return }
    switch call.method {
    case "outgoing":
      if active.contains(id) { result(true); return }
      let action = CXStartCallAction(call: id, handle: CXHandle(type: .generic, value: args["name"] as? String ?? "Cameo"))
      controller.request(CXTransaction(action: action)) { [weak self] error in
        DispatchQueue.main.async {
          if error == nil {
            self?.active.insert(id)
            self?.outgoing.insert(id)
            RTCAudioSession.sharedInstance().useManualAudio = true
            self?.provider.reportOutgoingCall(with: id, startedConnectingAt: Date())
          }
          result(error == nil)
        }
      }
    case "connected":
      answers.removeValue(forKey: id)?.fulfill()
      if outgoing.contains(id) { provider.reportOutgoingCall(with: id, connectedAt: Date()) }
      result(nil)
    case "ended": end(id, failed: args["failed"] as? Bool ?? false); result(nil)
    case "muted":
      if active.contains(id) {
        controller.request(CXTransaction(action: CXSetMutedCallAction(call: id, muted: args["muted"] as? Bool ?? false))) { _ in }
      }
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func end(_ id: UUID, failed: Bool) {
    outgoing.remove(id)
    answers.removeValue(forKey: id)?.fail()
    if active.remove(id) != nil { provider.reportCall(with: id, endedAt: Date(), reason: failed ? .failed : .remoteEnded) }
    if active.isEmpty { RTCAudioSession.sharedInstance().useManualAudio = false }
  }

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    setToken(pushCredentials.token, platform: "apns_voip")
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    if let token = tokens.removeValue(forKey: "apns_voip") { emit(["type": "token_invalidated", "token": token]) }
  }

  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType, completion: @escaping () -> Void) {
    let data = payload.dictionaryPayload
    let raw = data["call_id"] as? String
    let id = raw.flatMap(UUID.init(uuidString:)) ?? UUID()
    let ended = data["type"] as? String == "call_ended" || !enabled || raw == nil
    if active.contains(id) {
      if ended { end(id, failed: false) }
      completion(); return
    }
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: data["caller_name"] as? String ?? "Cameo")
    update.hasVideo = false
    // Report the system call immediately, including a late cancellation that the
    // application has not previously seen, before completing the VoIP push.
    provider.reportNewIncomingCall(with: id, update: update) { [weak self] error in
      DispatchQueue.main.async {
        guard let self = self else { completion(); return }
        if error == nil {
          self.active.insert(id)
          if ended { self.end(id, failed: false) }
          else {
            RTCAudioSession.sharedInstance().useManualAudio = true
            self.emit(["type": "incoming", "id": id.uuidString.lowercased()])
          }
        }
        completion()
      }
    }
  }

  func providerDidReset(_ provider: CXProvider) {
    for action in answers.values { action.fail() }
    answers.removeAll(); active.removeAll(); outgoing.removeAll()
    RTCAudioSession.sharedInstance().useManualAudio = false
    emit(["type": "reset"])
  }

  func provider(_ provider: CXProvider, perform action: CXStartCallAction) { action.fulfill() }
  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    answers[action.callUUID] = action
    emit(["type": "answer", "id": action.callUUID.uuidString.lowercased()])
  }
  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    active.remove(action.callUUID); answers.removeValue(forKey: action.callUUID)?.fail()
    emit(["type": "end", "id": action.callUUID.uuidString.lowercased()]); action.fulfill()
  }
  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    emit(["type": "mute", "muted": action.isMuted]); action.fulfill()
  }
  func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
    emit(["type": "reset"]); action.fail()
  }
  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = true
  }
  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = false
  }
}
