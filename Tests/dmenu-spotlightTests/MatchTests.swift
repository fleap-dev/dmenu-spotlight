import Testing
@testable import dmenu_spotlight

@Test func emptyInputKeepsEverythingInOrder() {
    #expect(match("", in: ["b", "a", "c"], caseInsensitive: false) == ["b", "a", "c"])
}

@Test func ordersExactThenPrefixThenSubstring() {
    let items = ["xfoo", "foobar", "foo", "bar"]
    #expect(match("foo", in: items, caseInsensitive: false) == ["foo", "foobar", "xfoo"])
}

@Test func everyWordMustMatch() {
    let items = ["git switch", "git status", "switch git", "ls"]
    #expect(match("git sw", in: items, caseInsensitive: false) == ["git switch", "switch git"])
}

@Test func caseSensitivity() {
    let items = ["Safari", "mail"]
    #expect(match("s", in: items, caseInsensitive: false) == [])
    #expect(match("s", in: items, caseInsensitive: true) == ["Safari"])
    #expect(match("MAIL", in: items, caseInsensitive: true) == ["mail"])
}
