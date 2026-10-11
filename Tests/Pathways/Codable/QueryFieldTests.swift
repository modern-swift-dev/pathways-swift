import Foundation
import Pathways
import Testing

struct QueryFieldTests {
    enum SortOrder: String, Codable, Equatable {
        case ascending = "asc"
        case descending = "desc"
    }

    struct SearchRoute: Pathway, Equatable {
        static let pattern = "/search/:category"

        let category: String
        var campaign: String?
        var page: Int
        var sort: SortOrder?

        enum CodingKeys: String, CodingKey {
            case category
            case campaign
            case page
            case sort = "order"
        }
    }

    private struct TypedQueryRoute: Pathway, Equatable {
        static let pattern = "/events"

        let id: UUID
        let since: Date
        let ratio: Double
        let isPublic: Bool
    }

    @Test func nonPlaceholderFieldsDecodeFromQueryParameters() throws {
        let url = try #require(URL(string: "https://localhost/search/books?page=2&campaign=summer&order=desc"))
        let route = try PathwayDecoder.shared.decode(SearchRoute.self, from: url)
        #expect(route == SearchRoute(category: "books", campaign: "summer", page: 2, sort: .descending))
    }

    @Test func absentOptionalQueryFieldsDecodeAsNil() throws {
        let url = try #require(URL(string: "https://localhost/search/books?page=1"))
        let route = try PathwayDecoder.shared.decode(SearchRoute.self, from: url)
        #expect(route == SearchRoute(category: "books", campaign: nil, page: 1, sort: nil))
    }

    @Test func absentRequiredQueryFieldNamesTheKey() throws {
        let url = try #require(URL(string: "https://localhost/search/books?campaign=summer"))
        #expect(throws: PathwayError.notFound(key: "page")) {
            try PathwayDecoder.shared.decode(SearchRoute.self, from: url)
        }
    }

    @Test func malformedQueryValueNamesTheKeyAndValue() throws {
        let url = try #require(URL(string: "https://localhost/search/books?page=two"))
        #expect(throws: PathwayError.notDecodable(key: "page", value: "two")) {
            try PathwayDecoder.shared.decode(SearchRoute.self, from: url)
        }
    }

    @Test func codingKeysNameTheQueryParameter() throws {
        let url = try #require(URL(string: "https://localhost/search/books?page=1&sort=asc"))
        #expect(try PathwayDecoder.shared.decode(SearchRoute.self, from: url).sort == nil)
    }

    @Test func encodingWritesQueryFieldsAndOmitsAbsentOptionals() throws {
        let route = SearchRoute(category: "books", campaign: nil, page: 2, sort: .ascending)
        #expect(try PathwayEncoder.shared.encode(route) == "/search/books?page=2&order=asc")
        #expect(try PathwayEncoder.shared.encode(SearchRoute(category: "books", page: 1)) == "/search/books?page=1")
    }

    @Test(arguments: ["summer", "", "a&b=c", "a+b c", "é#?/%"])
    func encodedURLsRoundTrip(_ campaign: String) throws {
        let route = SearchRoute(category: "a/b", campaign: campaign, page: 3, sort: .descending)
        let base = try #require(URL(string: "https://localhost"))
        let url = try #require(try PathwayEncoder.shared.encode(route, relativeTo: base))
        #expect(try PathwayDecoder.shared.decode(SearchRoute.self, from: url) == route)
    }

    @Test func scalarQueryFieldsRoundTrip() throws {
        let route = try TypedQueryRoute(
            id: #require(UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")),
            since: Date(timeIntervalSince1970: 1_700_000_000.5),
            ratio: 0.25,
            isPublic: true
        )
        let path = try PathwayEncoder.shared.encode(route)
        #expect(path == "/events?id=E621E1F8-C36C-495A-93FC-0C247A3E6E5F&since=2023-11-14T22:13:20.500Z&ratio=0.25&isPublic=true")
        let url = try #require(URL(string: "https://localhost" + path))
        #expect(try PathwayDecoder.shared.decode(TypedQueryRoute.self, from: url) == route)
    }

    @Test @MainActor func routedTypedHandlersReceiveQueryFields() throws {
        var router = PathwayRouter()
        var received: SearchRoute?
        router.register(host: "localhost", SearchRoute.self) { route, _ in received = route }

        #expect(try router.handle(#require(URL(string: "https://localhost/search/books?page=4&order=asc"))))
        #expect(received == SearchRoute(category: "books", campaign: nil, page: 4, sort: .ascending))
    }
}
