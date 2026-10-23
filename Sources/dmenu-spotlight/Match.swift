import Foundation

/// Filters `items` the way dmenu does. An item matches when it contains every
/// space-separated word of `input`. Exact matches come first, then items that
/// start with the first word, then the rest. Each group keeps the input order.
func match(_ input: String, in items: [String], caseInsensitive: Bool) -> [String] {
    let options: String.CompareOptions = caseInsensitive ? .caseInsensitive : []
    let words = input.split(separator: " ")
    var exact: [String] = [], prefix: [String] = [], rest: [String] = []

    for item in items where words.allSatisfy({ item.range(of: $0, options: options) != nil }) {
        if words.isEmpty || item.compare(input, options: options) == .orderedSame {
            exact.append(item)
        } else if item.range(of: words[0], options: options.union(.anchored)) != nil {
            prefix.append(item)
        } else {
            rest.append(item)
        }
    }
    return exact + prefix + rest
}
