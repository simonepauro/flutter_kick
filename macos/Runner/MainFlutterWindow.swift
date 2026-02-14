import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  private let minWidth: CGFloat = 500
  private let minHeight: CGFloat = 700

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    minSize = NSSize(width: minWidth, height: minHeight)

    // Titolo finestra (per Cmd+`, Dock, ecc.)
    title = "Flutter Kick"

    // Titolo centrato nella barra: nascondi il titolo di default e usa una toolbar
    titleVisibility = .hidden
    titlebarAppearsTransparent = false
    let toolbar = NSToolbar(identifier: "MainToolbar")
    toolbar.displayMode = .iconOnly
    toolbar.showsBaselineSeparator = false
    toolbar.delegate = self
    self.toolbar = toolbar

    RegisterGeneratedPlugins(registry: flutterViewController)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}

// MARK: - NSToolbarDelegate (titolo centrato)
extension MainFlutterWindow: NSToolbarDelegate {
  func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
    switch itemIdentifier {
    case .flexibleSpace:
      return NSToolbarItem(itemIdentifier: .flexibleSpace)
    case NSToolbarItem.Identifier("Title"):
      let item = NSToolbarItem(itemIdentifier: itemIdentifier)
      let label = NSTextField(labelWithString: "Flutter Kick")
      label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular), weight: .semibold)
      label.alignment = .center
      label.textColor = .labelColor
      label.sizeToFit()
      item.view = label
      item.minSize = NSSize(width: label.bounds.width, height: 22)
      return item
    default:
      return nil
    }
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [.flexibleSpace, NSToolbarItem.Identifier("Title"), .flexibleSpace]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [.flexibleSpace, NSToolbarItem.Identifier("Title")]
  }
}
