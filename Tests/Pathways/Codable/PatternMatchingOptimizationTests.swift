import Foundation
@testable import Pathways
import Testing

struct PatternMatchingOptimizationTests {
    @Test func matchesRegularExpressionsForBoundedCombinations() throws {
        let patternComponents = ["item", ":id", "a.b", "café", "", "%", "x+y"]
        let pathComponents = ["item", "a.b", "café", "a", "", ":literal", "%", "x+y"]
        var patterns = ["", "/", "//"]
        for first in patternComponents {
            patterns.append(first)
            for second in patternComponents {
                patterns.append("/\(first)/\(second)")
                for third in patternComponents {
                    patterns.append("/\(first)/\(second)/\(third)/")
                }
            }
        }
        var paths: [[String]] = [[]]
        for first in pathComponents {
            paths.append([first])
            for second in pathComponents {
                paths.append([first, second])
                for third in pathComponents {
                    paths.append([first, second, third])
                }
            }
        }

        for policy in [PathwayMatchPolicy.prefix, .exact] {
            for pattern in patterns {
                let matcher = PathwayMatcher(pattern: pattern, matching: policy)
                let regex = try referenceRegex(pattern: pattern, matching: policy)
                // URLs never produce a trailing empty component.
                for path in paths where path.last != "" {
                    let canonical = try canonicalPath(path)
                    let expected = regex.numberOfMatches(in: canonical, range: NSRange(canonical.startIndex ..< canonical.endIndex, in: canonical)) == 1
                    #expect(matcher.matches(path) == expected, "Pattern: \(pattern), policy: \(policy), path: \(path)")
                }
            }
        }
    }

    @Test func prefixPlaceholdersMatchOneNonEmptyComponent() throws {
        let matcher = PathwayMatcher(pattern: "/start/:first/middle/:last/end", matching: .prefix)
        #expect(try matcher.matches(components("/start/a/middle/b/end")))
        #expect(try matcher.matches(components("/start/a/middle/b/end/suffix")))
        #expect(try !matcher.matches(components("/start//middle//end")))
        #expect(try !matcher.matches(components("/start/a/b/middle/c/d/end")))
        #expect(try !matcher.matches(components("/start/a/middle/c/finish")))
    }

    @Test func prefixLiteralsEndOnComponentBoundaries() throws {
        let literal = PathwayMatcher(pattern: "/about", matching: .prefix)
        #expect(try literal.matches(components("/about")))
        #expect(try literal.matches(components("/about/team")))
        #expect(try !literal.matches(components("/aboutus")))

        let trailing = PathwayMatcher(pattern: "/products/:id/reviews", matching: .prefix)
        #expect(try trailing.matches(components("/products/1/reviews")))
        #expect(try trailing.matches(components("/products/1/reviews/2")))
        #expect(try !trailing.matches(components("/products/1/reviewsXYZ")))
        #expect(try !trailing.matches(components("/products/1/reviewsXYZ/reviews")))
    }

    @Test func literalPathsTreatColonsLiterally() throws {
        let matcher = PathwayMatcher(path: "/time/:now", matching: .exact)
        #expect(try matcher.matches(components("/time/:now")))
        #expect(try !matcher.matches(components("/time/12")))
    }

    private func components(_ path: String) throws -> [String] {
        try #require(URL(string: "https://localhost" + path)).pathwayPathComponents
    }

    /// Escapes each component so the regex can distinguish separators from escaped slashes.
    private func canonicalPath(_ components: [String]) throws -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        return try "/" + components.map { try #require($0.addingPercentEncoding(withAllowedCharacters: allowed)) }.joined(separator: "/")
    }

    private func referenceRegex(pattern: String, matching policy: PathwayMatchPolicy) throws -> NSRegularExpression {
        var expression = "^/"
        let components = pattern.split(separator: "/")
        for (index, component) in components.enumerated() {
            if index > 0 {
                expression += "/"
            }
            if component.hasPrefix(":") {
                expression += "[^/]+"
            } else {
                expression += try NSRegularExpression.escapedPattern(for: canonicalPath([String(component)]).dropFirst().description)
            }
        }
        switch policy {
            case .prefix where !components.isEmpty:
                expression += "(?=/|$)"
            case .prefix:
                break
            case .exact:
                expression += "$"
        }
        return try NSRegularExpression(pattern: expression)
    }
}
