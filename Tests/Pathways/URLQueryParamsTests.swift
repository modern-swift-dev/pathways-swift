import Foundation
@testable import Pathways
import Testing

@Suite(.serialized) struct URLQueryParamsTests {

    @Test func queryParamsReturnsQueryItems() throws {
        let url = try #require(URL(string: "https://example.com/path?one=1&two=2"))

        let params = url.queryParams.asDictionary

        #expect(params == ["one": "1", "two": "2"])
    }

    @Test func fragmentParamsReturnsItemsAfterQuestionMark() throws {
        let url = try #require(URL(string: "https://example.com/path#section?token=abc&mode=edit"))

        let params = url.fragmentParams.asDictionary

        #expect(params == ["token": "abc", "mode": "edit"])
    }

    @Test func fragmentParamsIgnoresFragmentsWithoutQuerySeparator() throws {
        let url = try #require(URL(string: "https://example.com/path#section"))

        #expect(url.fragmentParams.isEmpty)
    }

    @Test func fragmentParamsIgnoresMalformedPairs() throws {
        let url = try #require(URL(string: "https://example.com/path#section?valid=yes&missingValue&too=many=parts"))

        let params = url.fragmentParams.asDictionary

        #expect(params == ["valid": "yes"])
    }

    @Test func allParamsCombinesQueryAndFragmentParams() throws {
        let url = try #require(URL(string: "https://example.com/path?q=1#section?f=2"))

        let params = url.allParams.asDictionary

        #expect(params == ["q": "1", "f": "2"])
    }

    @Test func fragmentParametersDecodeOnlyAfterSplitting() throws {
        let url = try #require(URL(string: "https://example.com/path#complete?token=a%26b%3Dc&name=hello%20world&literal=a%2520b&question=a%3Fb&encoded%26key=value"))
        #expect(url.fragmentParams.asDictionary == [
            "token": "a&b=c",
            "name": "hello world",
            "literal": "a%20b",
            "question": "a?b",
            "encoded&key": "value"
        ])
    }
}
