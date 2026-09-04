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

    /// Return only the fragment params
    var fragmentParams: [URLQueryItem] {
        guard let fragment = URLComponents(url: self, resolvingAgainstBaseURL: false)?.percentEncodedFragment,
              let separator = fragment.firstIndex(of: "?") else {
            return []
        }
        let query = fragment[fragment.index(after: separator)...]
        return query.split(separator: "&").compactMap { pair in
            let parts = pair.split(separator: "=", omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty,
                  let name = String(parts[0]).removingPercentEncoding,
                  let value = String(parts[1]).removingPercentEncoding else {
                return nil
            }
            return URLQueryItem(name: name, value: value)
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
