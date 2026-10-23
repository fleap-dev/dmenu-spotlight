import Testing
@testable import dmenu_spotlight

@Test func defaults() throws {
    let options = try Options.parse([])
    #expect(options.prompt == "Search")
    #expect(options.caseInsensitive == false)
    #expect(options.lines == 8)
    #expect(options.showVersion == false)
}

@Test func supportedFlags() throws {
    let options = try Options.parse(["-i", "-l", "3", "-p", "Pick one", "-v"])
    #expect(options.prompt == "Pick one")
    #expect(options.caseInsensitive)
    #expect(options.lines == 3)
    #expect(options.showVersion)
}

@Test func ignoresDmenuAppearanceFlags() throws {
    let options = try Options.parse(["-b", "-f", "-m", "1", "-fn", "Mono-12", "-nb", "#000", "-nf", "#fff",
                                     "-sb", "#00f", "-sf", "#fff", "-w", "42", "-p", "Go"])
    #expect(options.prompt == "Go")
}

@Test(arguments: [["-x"], ["-p"], ["-l"], ["-l", "0"], ["-l", "two"], ["-fn"], ["item"]])
func rejectsBadArguments(arguments: [String]) {
    #expect(throws: Options.UsageError.self) { try Options.parse(arguments) }
}
