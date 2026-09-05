import Foundation

extension CharacterSet {
    static let pathwayComponentAllowed = urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
}

extension URL {

    /// Split before decoding so escaped delimiters remain part of their value.
    var pathwayPathComponents: [String] {
        guard let urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return []
        }

        var path = urlComponents.percentEncodedPath
        if path.hasPrefix("//") {
            path.removeFirst()
        }
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        var components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if components.last == "" {
            components.removeLast()
        }

        if let fragment = urlComponents.percentEncodedFragment {
            let route = fragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            if !route.isEmpty {
                components.append(contentsOf: ("#" + route).split(separator: "/", omittingEmptySubsequences: false).map(String.init))
            }
        }

        for index in components.indices {
            components[index] = components[index].removingPercentEncoding ?? components[index]
        }
        return components
    }

}

extension [String] {
    /// Canonical escaping lets matching distinguish a separator from an escaped slash.
    var pathwayMatchingPath: String {
        var path = "/"
        for (index, component) in enumerated() {
            if index > 0 {
                path += "/"
            }
            path += component.addingPercentEncoding(withAllowedCharacters: .pathwayComponentAllowed) ?? component
        }
        return path
    }
}
