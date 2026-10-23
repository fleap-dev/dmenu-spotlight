import AppKit

// Reads items from stdin, shows them in a Spotlight-style window, and prints
// the one the user picks. Exits with 0 after a pick, 1 on cancel or bad usage.

let options: Options
do {
    options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data((Options.usage + "\n").utf8))
    exit(1)
}

if options.showVersion {
    print("dmenu-spotlight \(Options.version)")
    exit(0)
}

let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
let items = input.split(whereSeparator: \.isNewline).map(String.init)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let menu = Menu(items: items, options: options) { choice in
    guard let choice else { exit(1) }
    print(choice)
    exit(0)
}
menu.show()
app.run()
