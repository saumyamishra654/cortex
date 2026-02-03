import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    let bookmarkChannel = FlutterMethodChannel(
      name: "cortex_app/macos_bookmarks",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    bookmarkChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "createBookmark":
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "ARGUMENT_ERROR", message: "Expected path string", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        do {
          let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
          result(data.base64EncodedString())
        } catch {
          result(FlutterError(code: "BOOKMARK_ERROR", message: error.localizedDescription, details: nil))
        }
      case "resolveBookmark":
        guard let base64 = call.arguments as? String, let data = Data(base64Encoded: base64) else {
          result(FlutterError(code: "ARGUMENT_ERROR", message: "Expected bookmark string", details: nil))
          return
        }
        var isStale = false
        do {
          let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
          _ = url.startAccessingSecurityScopedResource()
          result(["path": url.path, "stale": isStale])
        } catch {
          result(FlutterError(code: "BOOKMARK_ERROR", message: error.localizedDescription, details: nil))
        }
      case "stopAccessing":
        guard let base64 = call.arguments as? String, let data = Data(base64Encoded: base64) else {
          result(FlutterError(code: "ARGUMENT_ERROR", message: "Expected bookmark string", details: nil))
          return
        }
        var isStale = false
        do {
          let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
          url.stopAccessingSecurityScopedResource()
          result(true)
        } catch {
          result(FlutterError(code: "BOOKMARK_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
