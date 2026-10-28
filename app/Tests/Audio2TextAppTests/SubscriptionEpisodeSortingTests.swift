@testable import Audio2TextApp
import Audio2TextCore
import XCTest

final class SubscriptionEpisodeSortingTests: XCTestCase {
    func testSortToggleUsesPublicationDatesAndKeepsEqualDatesInConsistentOrder() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
        let oldest = testLibraryItem(
            id: "oldest",
            title: "Oldest",
            audioURL: root.appendingPathComponent("oldest.m4a"),
            publishedAt: "2026-07-01T00:00:00Z",
            modifiedAt: Date(timeIntervalSince1970: 300)
        )
        let newest = testLibraryItem(
            id: "newest",
            title: "Newest",
            audioURL: root.appendingPathComponent("newest.m4a"),
            publishedAt: "2026-07-03T00:00:00Z",
            modifiedAt: Date(timeIntervalSince1970: 100)
        )
        let middle = ["middle-b", "middle-a"].map { id in
            testLibraryItem(
                id: id,
                title: id,
                audioURL: root.appendingPathComponent("\(id).m4a"),
                publishedAt: "2026-07-02T00:00:00Z",
                modifiedAt: Date(timeIntervalSince1970: 200)
            )
        }
        let episodes = ([newest, oldest] + middle).map(SubscriptionEpisodeDisplayItem.init)
        var order = SubscriptionEpisodeSortOrder.newestFirst
        order = order.toggled
        let ascending = SubscriptionEpisodeFilters.filteredEpisodes(
            episodes, statusFilter: .all, timeFilter: .all, sortOrder: order
        )
        order = order.toggled
        let descending = SubscriptionEpisodeFilters.filteredEpisodes(
            episodes, statusFilter: .all, timeFilter: .all, sortOrder: order
        )

        XCTAssertEqual(ascending.map(\.id), ["oldest", "middle-a", "middle-b", "newest"])
        XCTAssertEqual(descending.map(\.id), ["newest", "middle-a", "middle-b", "oldest"])
    }

    func testFirstTenSelectionFollowsSortedAndFilteredEpisodes() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
        let now = try XCTUnwrap(LibraryDateParser.date(from: "2026-07-31T12:00:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let episodes = (1...25).map { day in
            testLibraryItem(
                id: "episode-\(day)",
                title: "Episode \(day)",
                audioURL: root.appendingPathComponent("\(day).m4a"),
                hasProcessed: day == 25,
                publishedAt: String(format: "2026-07-%02dT00:00:00Z", day),
                modifiedAt: now
            )
        }.map(SubscriptionEpisodeDisplayItem.init)

        for order in [SubscriptionEpisodeSortOrder.oldestFirst, .newestFirst] {
            let filtered = SubscriptionEpisodeFilters.filteredEpisodes(
                episodes,
                statusFilter: .unprocessed,
                timeFilter: .last30Days,
                sortOrder: order,
                now: now,
                calendar: calendar
            )
            let selected = SubscriptionBulkSelection.frontVisibleSelection(episodes: filtered, limit: 10)
            let expectedDays = order == .oldestFirst ? Array(2...11) : Array(15...24)

            XCTAssertEqual(selected, Set(expectedDays.map { "episode-\($0)" }))
            XCTAssertEqual(filtered.count, 23)
        }
    }
}
