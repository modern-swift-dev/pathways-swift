import Foundation

extension URL {

    /// Standard query items followed, when supported, by fragment query items,
    /// collected with a single URLComponents parse.
    func pathwayQueryItems(supportFragmentParams: Bool) -> [URLQueryItem] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return []
        }
        var items = components.queryItems ?? []
        if supportFragmentParams {
            Self.forEachFragmentParameter(in: components.percentEncodedFragment) { name, value in
                items.append(URLQueryItem(name: name, value: value))
            }
        }
        return items
    }

    private static func forEachFragmentParameter(in fragment: String?, _ body: (String, String?) -> Void) {
        guard let fragment, let separator = fragment.firstIndex(of: "?") else {
            return
        }
        let query = fragment[fragment.index(after: separator)...]
        for pair in query.split(separator: "&") {
            // A name without "=" is a flag without a value.
            let equals = pair.firstIndex(of: "=") ?? pair.endIndex
            let encodedName = pair[..<equals]
            let encodedValue = equals == pair.endIndex ? nil : pair[pair.index(after: equals)...]
            guard !encodedName.isEmpty, encodedValue?.contains("=") != true,
                  let name = String(encodedName).removingPercentEncoding else {
                continue
            }
            guard let encodedValue else {
                body(name, nil)
                continue
            }
            guard let value = String(encodedValue).removingPercentEncoding else {
                continue
            }
            body(name, value)
        }
    }

}

extension Sequence<URLQueryItem> {

    /// Return a dictionary for the current array of items.
    ///
    /// Items without a value map to an empty string, and the last repeated name wins.
    var asDictionary: [String: String] {
        reduce(into: [String: String]()) { partialResult, item in
            partialResult[item.name] = item.value ?? ""
        }
    }
}
