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

    @Test(arguments: [false, true]) func consolidatedParametersPreserveDuplicatesAndNilDeletion(_ supportFragmentParams: Bool) throws {
        let url =
            try #require(
                URL(
                    string: "https://example.com/path?duplicate=first&duplicate=last&deleted=value&deleted&empty=&token=query#section?token=fragment&duplicate=fragmentFirst&duplicate=fragmentLast&empty=&=ignored&missing&too=many=parts"
                )
            )
        let expected = supportFragmentParams
            ? ["duplicate": "fragmentLast", "empty": "", "token": "fragment"]
            : ["duplicate": "last", "empty": "", "token": "query"]
        #expect(url.pathwayParameters(supportFragmentParams: supportFragmentParams) == expected)
        #expect(url.pathwayParameters(supportFragmentParams: supportFragmentParams) == (supportFragmentParams ? url.allParams : url.queryParams).asDictionary)
    }

    @Test func consolidatedParametersPreserveEncodedSeparators() throws {
        let url = try #require(URL(string: "https://example.com/path?query=a%26b%3Dc#section?encoded%26key=a%3Db%26c&literal=a%2520b&question=a%3Fb"))
        #expect(url.pathwayParameters(supportFragmentParams: true) == [
            "query": "a&b=c",
            "encoded&key": "a=b&c",
            "literal": "a%20b",
            "question": "a?b"
        ])
    }

    @Test(arguments: ["https://example.com/path", "https://example.com/path?#section?", "https://example.com/path#section"]) func consolidatedParametersHandleEmptyQueries(_ address: String) throws {
        let url = try #require(URL(string: address))
        #expect(url.pathwayParameters(supportFragmentParams: true).isEmpty)
        #expect(url.pathwayParameters(supportFragmentParams: false).isEmpty)
    }

}
