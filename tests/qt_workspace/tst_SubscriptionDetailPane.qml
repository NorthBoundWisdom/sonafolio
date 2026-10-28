import QtQuick
import QtTest
import GeoControls 1.0
import "../../qt/Audio2TextQt/qml" as App

Rectangle {
    id: fixture
    width: 1100
    height: 720
    color: Theme.baseColor
    readonly property var feed: ({
        id: "feed", title: "A long podcast channel title for responsive layout",
        count: 9, unprocessedCount: 6, processedCount: 3, source: "podcast_rss",
        groupName: "Default", feedURL: "https://example.org/podcasts/feed.xml",
        createdAt: "2026-01-01", lastCheckedAt: "2026-10-14T08:00:00Z"
    })
    QtObject {
        id: mockLibrary
        property var selectedSubscription: fixture.feed
        property var subscriptions: [fixture.feed]
        property var selectedSubscriptionItems: {
            let items = [];
            for (let i = 0; i < 9; ++i) items.push({
                id: "episode-" + i, title: "A detailed episode title that can use the full reading pane width",
                hasProcessed: i < 3, hasFile: i === 5, isRead: false, isStarred: i === 1, status: "QA pass",
                queueStatus: "unread", publishedAt: "2026-10-0" + (i + 1) + "T08:00:00Z",
                modifiedAt: "2026-10-14T08:00:00", sourceURL: "https://example.org/podcasts/episodes/" + i
            });
            return items;
        }
        property string selectedSource: "subscriptions"
        property string openedId: ""
        property var archivedIds: []
        function selectItem(id) { openedId = id; }
        function setItemsArchived(ids, archived) { archivedIds = ids; }
    }
    QtObject {
        id: mockJobs
        property bool running: false
        property var batch: []
        function runBatchTranscribe(items) { batch = items; }
    }
    App.SubscriptionDetailPane {
        id: pane
        anchors.fill: parent
        library: mockLibrary
        jobs: mockJobs
    }

    TestCase {
        name: "SubscriptionDetailPane"
        when: windowShown
        function initTestCase() { failOnWarning(/.*/); }
        function init() {
            mockLibrary.selectedSubscription = fixture.feed;
            pane.statusFilter = "all";
            pane.timeFilter = "all";
            pane.newestFirst = true;
            pane.clearSelection();
        }
        function cleanup() { settingsController.appearanceMode = "system"; }

        function test_empty_selection_has_no_binding_warnings() {
            mockLibrary.selectedSubscription = ({});
            compare(pane.hasSubscription, false);
            compare(findChild(pane, "subscriptionTitle").text, "Subscriptions");
            compare(findChild(pane, "subscriptionSubtitle").text, "1 subscriptions");
            verify(!findChild(pane, "episodeToolbar").visible);
        }

        function test_layout_uses_pane_width_data() {
            return [
                { tag: "narrow", width: 360 },
                { tag: "medium", width: 700 },
                { tag: "wide", width: 1100 }
            ];
        }
        function test_layout_uses_pane_width(data) {
            fixture.width = data.width;
            settingsController.appearanceMode = "dark";
            let list = findChild(pane, "subscriptionEpisodeList");
            let episode = findChild(pane, "subscriptionEpisode_episode-0");
            tryVerify(function() { return Math.abs(list.width - data.width) <= 1; });
            fuzzyCompare(episode.width, data.width - 28, 1);
            let more = findChild(pane, "subscriptionMoreButton");
            verify(more.mapToItem(pane, more.width, 0).x <= pane.width - pane.sideMargin + 1);
            let sort = findChild(pane, "episodeSortOrder");
            verify(sort.mapToItem(pane, sort.width, 0).x <= pane.width - pane.sideMargin + 1);
            if (captureDirectory.length > 0) {
                wait(150); // Let control color transitions settle before capturing.
                let saved = false;
                verify(pane.grabToImage(function(result) {
                    saved = result.saveToFile(captureDirectory + "/subscription-" + data.tag + ".png");
                }));
                tryVerify(function() { return saved; });
            }
        }

        function test_filters_and_sort() {
            compare(pane.filteredEpisodes.length, 9);
            compare(pane.filteredEpisodes[0].id, "episode-8");
            pane.statusFilter = "processed";
            compare(pane.filteredEpisodes.length, 3);
            pane.statusFilter = "unprocessed";
            compare(pane.filteredEpisodes.length, 6);
            pane.newestFirst = false;
            compare(pane.filteredEpisodes[0].id, "episode-3");
        }

        function test_bulk_actions_replace_filters() {
            pane.selectFirst(10);
            compare(pane.selectedItems.length, 9);
            verify(findChild(pane, "episodeBulkActionBar").visible);
            verify(!findChild(pane, "episodeFilterBar").visible);
            compare(pane.processableItems.length, 1);
            mouseClick(findChild(pane, "processSelectedEpisodes"));
            compare(mockJobs.batch.length, 1);
            compare(mockJobs.batch[0].id, "episode-5");
            compare(pane.selectedItems.length, 0);
            pane.toggleSelection("episode-4");
            mouseClick(findChild(pane, "archiveSelectedEpisodes"));
            compare(mockLibrary.archivedIds, ["episode-4"]);
            verify(findChild(pane, "episodeFilterBar").visible);
        }

        function test_selection_drops_hidden_episodes() {
            pane.selectFirst(10);
            pane.statusFilter = "processed";
            compare(pane.selectedIds.length, 3);
        }

        function test_open_processed_episode_preserves_navigation() {
            pane.newestFirst = false;
            let open = findChild(pane, "openSubscriptionEpisode_episode-0");
            verify(open.visible);
            verify(!findChild(pane, "openSubscriptionEpisode_episode-4").visible);
            mouseClick(open);
            compare(mockLibrary.selectedSource, "library");
            compare(mockLibrary.openedId, "episode-0");
        }
    }
}
