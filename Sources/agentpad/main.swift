import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// .accessory: menu bar icon only, no Dock icon
app.setActivationPolicy(.accessory)
app.run()
