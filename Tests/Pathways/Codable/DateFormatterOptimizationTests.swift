import Foundation
@testable import Pathways
import Testing

struct DateFormatterOptimizationTests {
    @Test func wholeSecondsOmitTheFraction() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(ISO8601DateFormatter.pathwayString(from: date) == "2023-11-14T22:13:20Z")
        #expect(ISO8601DateFormatter.pathwayDate(from: "2023-11-14T22:13:20Z") == date)
        #expect(ISO8601DateFormatter.pathwayDate(from: "2023-11-14T23:13:20+01:00") == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(ISO8601DateFormatter.pathwayDate(from: "invalid") == nil)
    }

    @Test func fractionalSecondsRoundTripWithMillisecondPrecision() throws {
        let exact = Date(timeIntervalSince1970: 1_700_000_000.75)
        #expect(ISO8601DateFormatter.pathwayString(from: exact) == "2023-11-14T22:13:20.750Z")
        #expect(ISO8601DateFormatter.pathwayDate(from: "2023-11-14T22:13:20.750Z") == exact)

        let millisecond = Date(timeIntervalSince1970: 1_700_000_000.123)
        let decoded = try #require(ISO8601DateFormatter.pathwayDate(from: ISO8601DateFormatter.pathwayString(from: millisecond)))
        #expect(abs(decoded.timeIntervalSince(millisecond)) < 0.000_5)
    }

    @Test func concurrentFormattingAndParsingPreservesEachDate() async {
        let succeeded = await withTaskGroup(of: Bool.self) { group in
            for index in 0 ..< 100 {
                group.addTask {
                    let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) / 4)
                    let string = ISO8601DateFormatter.pathwayString(from: date)
                    return ISO8601DateFormatter.pathwayDate(from: string) == date
                }
            }
            for await success in group where !success {
                return false
            }
            return true
        }
        #expect(succeeded)
    }
}
