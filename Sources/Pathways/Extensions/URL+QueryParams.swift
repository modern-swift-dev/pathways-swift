import Foundation

extension URL {

    /// Query a consolidated list of all url params, both query and fragment
    var allParams: [URLQueryItem] {
        queryParams + fragmentParams
    }

    /// Return only the Query Parameters
    var queryParams: [URLQueryItem] {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    /// Collect routing parameters with a single URLComponents parse.
    func pathwayParameters(supportFragmentParams: Bool) -> [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        var parameters = (components.queryItems ?? []).asDictionary
        if supportFragmentParams {
            Self.forEachFragmentParameter(in: components.percentEncodedFragment) { name, value in
                parameters[name] = value
            }
        }
        return parameters
    }

    /// Return only the fragment params
    var fragmentParams: [URLQueryItem] {
        var parameters: [URLQueryItem] = []
        Self.forEachFragmentParameter(in: URLComponents(url: self, resolvingAgainstBaseURL: false)?.percentEncodedFragment) { name, value in
            parameters.append(URLQueryItem(name: name, value: value))
        }
        return parameters
    }

    private static func forEachFragmentParameter(in fragment: String?, _ body: (String, String) -> Void) {
        guard let fragment, let separator = fragment.firstIndex(of: "?") else {
            return
        }
        let query = fragment[fragment.index(after: separator)...]
        for pair in query.split(separator: "&") {
            guard let equals = pair.firstIndex(of: "=") else {
                continue
            }
            let encodedName = pair[..<equals]
            let encodedValue = pair[pair.index(after: equals)...]
            guard !encodedName.isEmpty, !encodedValue.isEmpty, !encodedValue.contains("="),
                  let name = String(encodedName).removingPercentEncoding,
                  let value = String(encodedValue).removingPercentEncoding else {
                continue
            }
            body(name, value)
        }
    }

}

extension Sequence<URLQueryItem> {

    /// Return a dictionary for the the current array of items
    var asDictionary: [String: String] {
        reduce(into: [String: String]()) { partialResult, item in
            partialResult[item.name] = item.value
        }
    }
}
