/// Command-line options. The flags mirror dmenu's. Flags that only control
/// dmenu's look or placement are accepted and ignored, so existing dmenu
/// scripts don't fail on them.
struct Options {
    static let version = "0.1.0"
    static let usage = "usage: dmenu-spotlight [-i] [-l lines] [-p prompt] [-v]"

    var prompt = "Search"
    var caseInsensitive = false
    var lines = 8
    var showVersion = false

    struct UsageError: Error {}

    /// Parses the arguments that follow the program name.
    static func parse(_ arguments: [String]) throws(UsageError) -> Options {
        var options = Options()
        var args = arguments.makeIterator()

        // Returns the argument after a flag that takes a value, like `-p`.
        func value() throws(UsageError) -> String {
            guard let value = args.next() else { throw UsageError() }
            return value
        }

        while let flag = args.next() {
            switch flag {
            case "-v": options.showVersion = true
            case "-i": options.caseInsensitive = true
            case "-p": options.prompt = try value()
            case "-l":
                guard let lines = try Int(value()), lines > 0 else { throw UsageError() }
                options.lines = lines
            case "-b", "-f": break
            case "-m", "-w", "-fn", "-nb", "-nf", "-sb", "-sf": _ = try value()
            default: throw UsageError()
            }
        }
        return options
    }
}
