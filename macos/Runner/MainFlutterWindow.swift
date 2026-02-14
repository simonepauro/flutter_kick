import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let minWidth: CGFloat = 500
  private let minHeight: CGFloat = 700

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    minSize = NSSize(width: minWidth, height: minHeight)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
