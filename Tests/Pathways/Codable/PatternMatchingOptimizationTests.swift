import Foundation
@testable import Pathways
import Testing

struct PatternMatchingOptimizationTests {
    @Test func matchesLegacyRegularExpressionsForBoundedCombinations() throws {
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
        var paths = ["/", "", "missing/leading/slash"]
        for first in pathComponents {
            paths.append([first].pathwayMatchingPath)
            for second in pathComponents {
                paths.append([first, second].pathwayMatchingPath)
                for third in pathComponents {
                    paths.append([first, second, third].pathwayMatchingPath)
                }
            }
        }

        for policy in [PathwayMatchPolicy.prefix, .exact] {
            for pattern in patterns {
                let matcher = PathwayMatcher(pattern: pattern, matching: policy)
                let legacy = try legacyRegex(pattern: pattern, matching: policy)
                for path in paths {
                    let expected = legacy.numberOfMatches(in: path, range: NSRange(path.startIndex ..< path.endIndex, in: path)) == 1
                    #expect(matcher.matches(path) == expected, "Pattern: \(pattern), policy: \(policy), path: \(path)")
                }
            }
        }
    }

    @Test func prefixWildcardsCanMatchEmptyValuesAndMultipleComponents() {
        let matcher = PathwayMatcher(pattern: "/start/:first/middle/:last/end", matching: .prefix)
        #expect(matcher.matches("/start//middle//end/suffix"))
        #expect(matcher.matches("/start/a/b/middle/c/d/end"))
        #expect(matcher.matches("/start/middle/middle/c/end"))
        #expect(!matcher.matches("/start/a/middle/c/finish"))
    }

    @Test func repeatedWildcardsRejectMissingSuffixWithoutBacktracking() {
        let pattern = String(repeating: "/:value", count: 100) + "/required"
        let matcher = PathwayMatcher(pattern: pattern, matching: .prefix)
        let path = String(repeating: "/value", count: 1000)
        #expect(!matcher.matches(path))
        #expect(matcher.matches(path + "/required"))
    }

    private func legacyRegex(pattern: String, matching policy: PathwayMatchPolicy) throws -> NSRegularExpression {
        var expression = "^/"
        let components = pattern.split(separator: "/")
        for (index, component) in components.enumerated() {
            if index > 0 {
                expression += "/"
            }
            if component.hasPrefix(":") {
                switch policy {
                    case .prefix:
                        expression += ".*"
                    case .exact:
                        expression += "[^/]+"
                }
            } else {
                let literal = try #require(component.addingPercentEncoding(withAllowedCharacters: .pathwayComponentAllowed))
                expression += NSRegularExpression.escapedPattern(for: literal)
            }
        }
        if case .exact = policy {
            expression += "$"
        }
        return try NSRegularExpression(pattern: expression)
    }
}
