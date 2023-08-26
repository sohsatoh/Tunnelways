import SwiftUI

struct WillDisappearHandler: NSViewControllerRepresentable {
  let callback: () -> Void

  func makeNSViewController(context _: Context) -> NSViewController {
    VC(callback: callback)
  }

  func updateNSViewController(_: NSViewController, context _: Context) {}

  class VC: NSViewController {
    let callback: () -> Void

    init(callback: @escaping () -> Void) {
      self.callback = callback
      super.init(nibName: nil, bundle: nil)
      view = NSView()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewWillDisappear() {
      super.viewWillDisappear()
      callback()
    }
  }
}

extension View {
  func onWillDisappear(_ perform: @escaping () -> Void) -> some View {
    background(WillDisappearHandler(callback: perform))
  }
}
