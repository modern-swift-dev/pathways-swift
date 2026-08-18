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
        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
           let fragment = components.fragment, !fragment.isEmpty {
            let fragmentParts = fragment.split(separator: "?")
            if fragmentParts.count == 2 {
                return String(fragmentParts[1]).split(separator: "&")
                    .map { String($0) }
                    .compactMap { value -> URLQueryItem? in
                        let values = value.split(separator: "=")
                        if values.count == 2 {
                            return URLQueryItem(
                                name: String(values[0]),
                                value: String(values[1])
                            )
                        } else {
                            return nil
                        }
                    }
            }
        }
        return []
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
