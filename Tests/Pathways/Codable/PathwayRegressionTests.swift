import Foundation
import Pathways
import Testing

struct PathwayRegressionTests {

    private struct DateRoute: Pathway {
        static let pattern = "/date/:date"
        let date: Date
    }

    @Test func invalidDateThrowsAndValidDateDecodes() throws {
        let invalid = try #require(URL(string: "https://localhost/date/garbage"))
        #expect(throws: PathwayError.notDecodable) {
            try PathwayDecoder.shared.decode(DateRoute.self, from: invalid)
        }
        let valid = try #require(URL(string: "https://localhost/date/2026-09-04T12:00:00Z"))
        let date = try PathwayDecoder.shared.decode(DateRoute.self, from: valid).date
        #expect(date.timeIntervalSince1970 == 1_788_523_200)
    }

}
