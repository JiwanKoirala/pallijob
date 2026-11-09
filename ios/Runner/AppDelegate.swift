import Flutter
import SwiftUI
import Translation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var translationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PalliJobTranslation")
    else {
      assertionFailure("Could not register the PalliJob translation channel.")
      return
    }
    let channel = FlutterMethodChannel(
      name: "pallijob/job_translation",
      binaryMessenger: registrar.messenger()
    )
    translationChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isSupported":
        Task { @MainActor in
          if #available(iOS 18.0, *) {
            result(await AppleJobTranslation.isSupported())
          } else {
            result(false)
          }
        }
      case "isModelDownloaded":
        Task { @MainActor in
          if #available(iOS 18.0, *) {
            result(await AppleJobTranslation.isModelDownloaded())
          } else {
            result(false)
          }
        }
      case "translate":
        guard let content = call.arguments as? [String: String], !content.isEmpty else {
          result(FlutterError(
            code: "invalid_arguments",
            message: "No job text was provided.",
            details: nil
          ))
          return
        }
        Task { @MainActor in
          guard let self else {
            result(FlutterError(code: "translation_unavailable", message: nil, details: nil))
            return
          }
          self.presentTranslation(content: content, result: result)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @MainActor
  private func presentTranslation(content: [String: String], result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *),
      let presenter = UIApplication.shared.activeViewController
    else {
      result(FlutterError(
        code: "unsupported",
        message: "Translation is unavailable on this iOS version or device.",
        details: nil
      ))
      return
    }

    let flow = AppleTranslationFlow(content: content, presenter: presenter, result: result)
    let view = AppleTranslationView(flow: flow)
    let controller = UIHostingController(rootView: view)
    controller.modalPresentationStyle = .overFullScreen
    presenter.present(controller, animated: true)
  }
}

@available(iOS 18.0, *)
private enum AppleJobTranslation {
  static let source = Locale.Language(identifier: "ko-KR")
  static let target = Locale.Language(identifier: "en-US")

  static func isSupported() async -> Bool {
    #if targetEnvironment(simulator)
      return false
    #else
    let status = await LanguageAvailability().status(from: source, to: target)
    return status != .unsupported
    #endif
  }

  static func isModelDownloaded() async -> Bool {
    let status = await LanguageAvailability().status(from: source, to: target)
    return status == .installed
  }
}

@available(iOS 18.0, *)
@MainActor
private enum AppleTranslationOutcome {
  case success([String: String])
  case failure(FlutterError)
}

@available(iOS 18.0, *)
@MainActor
private final class AppleTranslationFlow: ObservableObject {
  @Published var status = "Preparing on-device translation…"

  let content: [String: String]
  let configuration = TranslationSession.Configuration(
    source: AppleJobTranslation.source,
    target: AppleJobTranslation.target
  )

  private weak var presenter: UIViewController?
  private var result: FlutterResult?
  private var didStart = false

  init(content: [String: String], presenter: UIViewController, result: @escaping FlutterResult) {
    self.content = content
    self.presenter = presenter
    self.result = result
  }

  func translate(using session: TranslationSession) async {
    guard !didStart else { return }
    didStart = true
    status = "Preparing Korean and English language resources…"

    do {
      try await session.prepareTranslation()
    } catch {
      finish(.failure(FlutterError(
        code: "model_download_failed",
        message: error.localizedDescription,
        details: nil
      )))
      return
    }

    status = "Translating on this device…"
    var translated: [String: String] = [:]
    do {
      for (field, text) in content {
        translated[field] = try await session.translate(text).targetText
      }
    } catch {
      finish(.failure(FlutterError(
        code: "translation_failed",
        message: error.localizedDescription,
        details: nil
      )))
      return
    }
    finish(.success(translated))
  }

  func cancel() {
    finish(.failure(FlutterError(
      code: "translation_cancelled",
      message: "Translation was cancelled.",
      details: nil
    )))
  }

  private func finish(_ outcome: AppleTranslationOutcome) {
    guard let result else { return }
    self.result = nil
    let deliverResult = {
      switch outcome {
      case .success(let translations):
        result(translations)
      case .failure(let error):
        result(error)
      }
    }
    if let presenter {
      presenter.dismiss(animated: true, completion: deliverResult)
    } else {
      deliverResult()
    }
  }
}

@available(iOS 18.0, *)
private struct AppleTranslationView: View {
  @ObservedObject var flow: AppleTranslationFlow

  var body: some View {
    VStack(spacing: 20) {
      ProgressView()
        .tint(Color(red: 0.14, green: 0.46, blue: 0.27))
      Text(flow.status)
        .font(.headline)
        .multilineTextAlignment(.center)
      Text("Apple may ask to download language resources the first time. Translation runs on this device.")
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      Button("Cancel", role: .cancel, action: flow.cancel)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
    .translationTask(flow.configuration) { session in
      await flow.translate(using: session)
    }
  }
}

private extension UIApplication {
  var activeViewController: UIViewController? {
    let windowScene = connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = windowScene?.windows.first(where: \.isKeyWindow)?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
