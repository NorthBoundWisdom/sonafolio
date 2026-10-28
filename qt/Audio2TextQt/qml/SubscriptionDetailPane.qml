import QtQuick
import QtQuick.Controls as QQC
import GeoControls 1.0
import QtQuick.Layouts

// Mirrors app/Sources/Audio2TextApp/SubscriptionDetailView.swift: header actions,
// status/time/sort filters, multi-selection bulk actions, and in-place episode details.
CustomPane {
    id: root
    padding: 0
    property var library: libraryController
    property var jobs: jobController
    background: Rectangle {
        color: Theme.baseColor
    }

    readonly property int refreshLimit: 10
    readonly property var subscription: library.selectedSubscription || ({})
    readonly property var episodes: library.selectedSubscriptionItems || []
    readonly property string subscriptionId: subscription.id || ""
    readonly property bool hasSubscription: subscriptionId.length > 0
    readonly property bool busy: jobs.running
    readonly property bool compact: width < 560
    readonly property int sideMargin: compact ? 14 : 22

    property string statusFilter: "all"
    property string timeFilter: "all"
    property bool newestFirst: true
    property var selectedIds: []
    property var presentedEpisode: null

    readonly property var timeFilters: [
        { id: "all", title: "All time" },
        { id: "today", title: "Today" },
        { id: "last7Days", title: "Last 7 days" },
        { id: "last30Days", title: "Last 30 days" },
        { id: "last90Days", title: "Last 90 days" },
        { id: "thisYear", title: "This year" }
    ]
    readonly property var statusFilters: [
        { id: "all", title: "All" },
        { id: "unprocessed", title: "Unprocessed" },
        { id: "processed", title: "Processed" }
    ]
    readonly property int processedCount: countProcessed(episodes)
    readonly property var counts: ({
        all: episodes.length,
        unprocessed: episodes.length - processedCount,
        processed: processedCount
    })
    readonly property var filteredEpisodes: filterEpisodes(episodes, statusFilter, timeFilter, newestFirst)
    readonly property var selectedItems: filteredEpisodes.filter(function(item) { return selectedIds.indexOf(item.id) >= 0; })
    readonly property var processableItems: selectedItems.filter(function(item) { return !item.hasProcessed && item.hasFile; })
    readonly property bool hasSelection: selectedItems.length > 0
    readonly property bool allVisibleSelected: filteredEpisodes.length > 0 && selectedItems.length === filteredEpisodes.length

    onSubscriptionIdChanged: clearSelection()
    onFilteredEpisodesChanged: reconcileSelection()

    function countProcessed(items) {
        let count = 0;
        for (let i = 0; i < items.length; ++i)
            if (items[i].hasProcessed)
                ++count;
        return count;
    }

    function parseDate(value) {
        if (!value)
            return null;
        let date = new Date(value);
        return isNaN(date.getTime()) ? null : date;
    }

    function episodeDate(item) {
        return parseDate(item.publishedAt) || parseDate(item.modifiedAt) || new Date(0);
    }

    function startOfDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }

    function includesTime(date, filter) {
        let now = new Date();
        let today = startOfDay(now);
        if (filter === "today")
            return startOfDay(date).getTime() === today.getTime();
        if (filter === "thisYear")
            return date.getFullYear() === now.getFullYear();
        let days = { last7Days: 7, last30Days: 30, last90Days: 90 }[filter];
        if (days === undefined)
            return true;
        return date >= new Date(today.getFullYear(), today.getMonth(), today.getDate() - (days - 1));
    }

    function filterEpisodes(items, status, time, newest) {
        let matches = items.filter(function(item) {
            if (status === "unprocessed" && item.hasProcessed)
                return false;
            if (status === "processed" && !item.hasProcessed)
                return false;
            return includesTime(episodeDate(item), time);
        });
        matches.sort(function(lhs, rhs) {
            let delta = episodeDate(lhs) - episodeDate(rhs);
            if (delta === 0)
                return lhs.id < rhs.id ? -1 : lhs.id > rhs.id ? 1 : 0;
            return newest ? -delta : delta;
        });
        return matches;
    }

    function relativeTime(date) {
        let seconds = Math.round((new Date() - date) / 1000);
        if (seconds < 60)
            return "now";
        let units = [[86400 * 365, "year"], [86400 * 30, "month"], [86400 * 7, "week"], [86400, "day"], [3600, "hour"], [60, "minute"]];
        for (let i = 0; i < units.length; ++i) {
            let value = Math.floor(seconds / units[i][0]);
            if (value >= 1) {
                if (units[i][1] === "day" && value === 1)
                    return "yesterday";
                return value + " " + units[i][1] + (value === 1 ? "" : "s") + " ago";
            }
        }
        return "now";
    }

    function headerSubtitle() {
        if (!hasSubscription)
            return library.subscriptions.length > 0 ? library.subscriptions.length + " subscriptions" : "No subscriptions yet";
        let parts = [counts.all + " episodes", counts.processed + " processed"];
        let checked = parseDate(subscription.lastCheckedAt);
        if (checked)
            parts.push("Checked " + relativeTime(checked));
        return parts.join(" · ");
    }

    function feedLink(sub) {
        let feed = (sub.feedURL || "").trim();
        return feed.length > 0 ? feed : (sub.url || "").trim();
    }

    function clean(value) {
        let text = value === undefined || value === null ? "" : String(value).trim();
        return text.length > 0 ? text : "";
    }

    function queueTitle(status) {
        return { to_process: "Process", process_later: "Later", "delete": "Delete" }[status] || "Unread";
    }

    function episodeCaption(item) {
        let date = Qt.formatDate(episodeDate(item), "MMM d, yyyy");
        return [date, clean(item.status), queueTitle(item.queueStatus)].filter(function(part) { return part.length > 0; }).join(" · ");
    }

    function copyText(text) {
        clipboardBuffer.text = text;
        clipboardBuffer.selectAll();
        clipboardBuffer.copy();
        clipboardBuffer.text = "";
    }

    function isSelected(id) {
        return selectedIds.indexOf(id) >= 0;
    }

    function toggleSelection(id) {
        let next = selectedIds.slice();
        let index = next.indexOf(id);
        if (index >= 0)
            next.splice(index, 1);
        else
            next.push(id);
        selectedIds = next;
    }

    function selectFirst(limit) {
        selectedIds = filteredEpisodes.slice(0, limit).map(function(item) { return item.id; });
    }

    function clearSelection() {
        if (selectedIds.length > 0)
            selectedIds = [];
    }

    function reconcileSelection() {
        let visible = filteredEpisodes.map(function(item) { return item.id; });
        let next = selectedIds.filter(function(id) { return visible.indexOf(id) >= 0; });
        if (next.length !== selectedIds.length)
            selectedIds = next;
    }

    function openInLibrary(item) {
        episodeDialog.close();
        library.selectedSource = "library";
        library.selectItem(item.id);
    }

    function presentEpisode(item) {
        presentedEpisode = item;
        episodeDialog.open();
    }

    TextEdit {
        id: clipboardBuffer
        visible: false
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.hasSelection && root.visible
        onActivated: root.clearSelection()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            objectName: "subscriptionHeader"
            Layout.fillWidth: true
            Layout.leftMargin: root.sideMargin
            Layout.rightMargin: root.sideMargin
            Layout.topMargin: 14
            Layout.bottomMargin: 14
            spacing: 8

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                CustomLabel {
                    objectName: "subscriptionTitle"
                    text: root.hasSubscription ? root.clean(root.subscription.title) : "Subscriptions"
                    color: Theme.textColor
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                CustomLabel {
                    objectName: "subscriptionSubtitle"
                    text: root.headerSubtitle()
                    color: Theme.placeholderTextColor
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            CustomButton {
                objectName: "refreshSubscription"
                visible: root.hasSubscription
                text: root.busy ? "Refreshing" : "↻  Refresh"
                tooltipText: "Check the feed for new episodes"
                enabled: !root.busy
                onClicked: root.jobs.refreshSubscriptions(false, root.subscription.id, root.refreshLimit)
            }

            CustomButton {
                id: moreButton
                objectName: "subscriptionMoreButton"
                visible: root.hasSubscription
                text: "…"
                tooltipText: "More actions"
                Accessible.name: "More subscription actions"
                onClicked: moreMenu.open()

                CustomMenu {
                    id: moreMenu
                    y: parent.height + 6
                    padding: 8
                    menuWidth: 240
                    MenuEntry {
                        text: "Subscription Info"
                        onTriggered: subscriptionInfoDialog.open()
                    }
                    MenuEntry {
                        text: "Copy Feed Link"
                        enabled: root.feedLink(root.subscription).length > 0
                        onTriggered: root.copyText(root.feedLink(root.subscription))
                    }
                    CustomMenuSeparator {}
                    MenuEntry {
                        text: "Fetch Complete History"
                        enabled: !root.busy
                        onTriggered: root.jobs.fetchSubscriptionHistory(root.subscription.id)
                    }
                    CustomMenuSeparator {}
                    MenuEntry {
                        text: "Remove Subscription…"
                        enabled: !root.busy
                        onTriggered: removeDialog.open()
                    }
                }
            }
        }

        Divider {}

        Placeholder {
            visible: !root.hasSubscription || root.episodes.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: root.hasSubscription ? "No episodes yet"
                : root.library.subscriptions.length > 0 ? "Select a subscription" : "No subscriptions"
            message: root.hasSubscription ? "Refresh the subscription to import its latest episodes."
                : root.library.subscriptions.length > 0 ? "Choose a subscription in the sidebar to browse its episodes."
                : "Add a podcast or RSS feed to create metadata-only episode records."
        }

        // Filters and bulk actions share one fixed-height slot, so selecting never shifts the list.
        RowLayout {
            objectName: "episodeToolbar"
            visible: root.hasSubscription && root.episodes.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            Layout.leftMargin: root.sideMargin
            Layout.rightMargin: root.sideMargin
            spacing: 8

            SelectionButton {
                objectName: "episodeSelectionMenuButton"
                text: root.selectedIds.length === 0 ? "○" : root.allVisibleSelected ? "◉" : "⊝"
                buttonTextColor: root.selectedIds.length === 0 ? Theme.placeholderTextColor : Theme.highlightColor
                tooltipText: "Select episodes"
                Accessible.name: "Select episodes"
                Accessible.description: root.selectedItems.length + " selected"
                onClicked: selectionMenu.open()

                CustomMenu {
                    id: selectionMenu
                    y: parent.height + 6
                    padding: 8
                    menuWidth: 220
                    MenuEntry {
                        objectName: "selectAllEpisodes"
                        text: "Select All (" + root.filteredEpisodes.length + ")"
                        enabled: root.filteredEpisodes.length > 0 && !root.allVisibleSelected
                        onTriggered: root.selectFirst(root.filteredEpisodes.length)
                    }
                    MenuEntry {
                        text: "Select First 10"
                        enabled: root.filteredEpisodes.length > 0
                        onTriggered: root.selectFirst(10)
                    }
                    CustomMenuSeparator {}
                    MenuEntry {
                        text: "Deselect All"
                        enabled: root.selectedIds.length > 0
                        onTriggered: root.clearSelection()
                    }
                }
            }

            RowLayout {
                objectName: "episodeFilterBar"
                visible: !root.hasSelection
                Layout.fillWidth: true
                spacing: 8

                CustomButton {
                    objectName: "episodeStatusMenuButton"
                    visible: root.compact
                    text: root.statusFilters.filter(function(f) { return f.id === root.statusFilter; })[0].title
                        + " " + root.counts[root.statusFilter] + "  ▾"
                    Accessible.name: "Episode status"
                    onClicked: statusMenu.open()

                    CustomMenu {
                        id: statusMenu
                        y: parent.height + 6
                        padding: 8
                        menuWidth: 200
                        StatusFilterEntry { index: 0 }
                        StatusFilterEntry { index: 1 }
                        StatusFilterEntry { index: 2 }
                    }
                }

                CustomPane {
                    objectName: "episodeStatusFilter"
                    visible: !root.compact
                    padding: 3
                    Layout.minimumWidth: 0
                    background: Rectangle {
                        radius: 8
                        color: Theme.alternateBaseColor
                    }
                    contentItem: Row {
                        spacing: 2
                        Repeater {
                            model: root.statusFilters
                            delegate: CustomButton {
                                id: segment
                                objectName: "episodeStatus_" + modelData.id
                                readonly property bool selected: root.statusFilter === modelData.id
                                text: modelData.title + (root.width >= 640 ? " " + root.counts[modelData.id] : "")
                                defaultHeight: 28
                                defaultPadding: 10
                                font.pixelSize: 13
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: selected
                                onClicked: root.statusFilter = modelData.id
                                background: Rectangle {
                                    radius: 6
                                    color: segment.down ? Theme.buttonPressedColor : segment.selected
                                        ? Theme.contentSurfaceColor : segment.hovered ? Theme.buttonHoveredColor : "transparent"
                                    border.width: segment.visualFocus ? 2 : 0
                                    border.color: Theme.accentColor
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                CustomButton {
                    id: timeButton
                    objectName: "episodeTimeFilter"
                    readonly property string currentTitle: root.timeFilters.filter(function(f) { return f.id === root.timeFilter; })[0].title
                    text: (root.compact && root.timeFilter === "all" ? "Date" : currentTitle) + "  ▾"
                    buttonTextColor: root.timeFilter === "all" ? Theme.textColor : Theme.highlightColor
                    tooltipText: "Publication date: " + currentTitle.toLowerCase()
                    Accessible.name: "Episode time range"
                    onClicked: timeMenu.open()

                    CustomMenu {
                        id: timeMenu
                        y: parent.height + 6
                        padding: 8
                        menuWidth: 180
                        TimeFilterEntry { index: 0 }
                        TimeFilterEntry { index: 1 }
                        TimeFilterEntry { index: 2 }
                        TimeFilterEntry { index: 3 }
                        TimeFilterEntry { index: 4 }
                        TimeFilterEntry { index: 5 }
                    }
                }

                CustomButton {
                    objectName: "episodeSortOrder"
                    text: root.newestFirst ? "↓" : "↑"
                    tooltipText: root.newestFirst ? "Newest first" : "Oldest first"
                    Accessible.name: "Sort by publication date"
                    Accessible.description: tooltipText
                    onClicked: root.newestFirst = !root.newestFirst
                }
            }

            RowLayout {
                objectName: "episodeBulkActionBar"
                visible: root.hasSelection
                Layout.fillWidth: true
                spacing: 8

                CustomLabel {
                    objectName: "episodeSelectionCount"
                    text: root.selectedItems.length + " selected"
                    color: Theme.textColor
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                CustomButton {
                    objectName: "processSelectedEpisodes"
                    text: "▶  Process"
                    highlighted: true
                    enabled: !root.busy && root.processableItems.length > 0
                    tooltipText: root.processableItems.length > 0
                        ? "Transcribe " + root.processableItems.length + " downloaded episodes"
                        : "Only unprocessed episodes with downloaded audio can be transcribed"
                    onClicked: {
                        root.jobs.runBatchTranscribe(root.processableItems);
                        root.clearSelection();
                    }
                }
                CustomButton {
                    objectName: "archiveSelectedEpisodes"
                    text: "Archive"
                    enabled: !root.busy
                    tooltipText: "Archive selected"
                    onClicked: {
                        root.library.setItemsArchived(root.selectedItems.map(function(item) { return item.id; }), true);
                        root.clearSelection();
                    }
                }
                CustomButton {
                    objectName: "clearEpisodeSelection"
                    text: "Done"
                    Accessible.name: "Deselect all"
                    onClicked: root.clearSelection()
                }
            }
        }

        Divider {
            visible: root.hasSubscription && root.episodes.length > 0
        }

        Placeholder {
            visible: root.hasSubscription && root.episodes.length > 0 && root.filteredEpisodes.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "No matching episodes"
            message: "Change the status or time range filters to see more episodes."
        }

        ListView {
            id: episodeList
            objectName: "subscriptionEpisodeList"
            visible: root.filteredEpisodes.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            topMargin: 6
            bottomMargin: 6
            leftMargin: 14
            rightMargin: 14
            spacing: 2
            model: root.filteredEpisodes
            QQC.ScrollBar.vertical: CustomScrollBar {}

            delegate: Rectangle {
                id: episodeRow
                objectName: "subscriptionEpisode_" + modelData.id
                readonly property bool selected: root.isSelected(modelData.id)
                width: ListView.view.width - 28
                height: 54
                radius: 8
                color: selected ? Theme.actionButtonHoveredColor : rowArea.containsMouse ? Theme.railSurfaceColor : "transparent"

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Show episode details for " + modelData.title
                    onClicked: root.presentEpisode(modelData)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 8
                    spacing: 8

                    SelectionButton {
                        objectName: "selectSubscriptionEpisode_" + modelData.id
                        text: episodeRow.selected ? "◉" : "○"
                        buttonTextColor: episodeRow.selected ? Theme.highlightColor : Theme.placeholderTextColor
                        Layout.preferredWidth: 36
                        Accessible.name: (episodeRow.selected ? "Deselect " : "Select ") + modelData.title
                        onClicked: root.toggleSelection(modelData.id)
                    }

                    ColumnLayout {
                        spacing: 3
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        CustomLabel {
                            text: modelData.title
                            color: Theme.textColor
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            spacing: 5
                            Layout.fillWidth: true
                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: modelData.hasProcessed ? Theme.successColor : Theme.placeholderTextColor
                                Accessible.ignored: true
                            }
                            CustomLabel {
                                text: root.episodeCaption(modelData)
                                color: Theme.placeholderTextColor
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    CustomLabel {
                        visible: modelData.isStarred === true
                        text: "★"
                        color: Theme.warningColor
                        font.pixelSize: 12
                        Accessible.name: "Starred"
                    }

                    CustomButton {
                        objectName: "openSubscriptionEpisode_" + modelData.id
                        visible: modelData.hasProcessed === true
                        text: "Open"
                        defaultHeight: 26
                        tooltipText: "Open transcript in Library"
                        Accessible.name: "Open " + modelData.title + " in Library"
                        onClicked: root.openInLibrary(modelData)
                    }
                }
            }
        }
    }

    CustomDialog {
        id: subscriptionInfoDialog
        objectName: "subscriptionInfoDialog"
        title: root.clean(root.subscription.title)
        modal: true
        parent: QQC.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(520, root.width - 40)
        standardButtons: QQC.Dialog.Ok

        ColumnLayout {
            anchors.fill: parent
            spacing: 9
            InfoRow {
                title: "Episodes"
                value: root.counts.all + " total · " + root.counts.unprocessed + " unprocessed · " + root.counts.processed + " processed"
            }
            InfoRow { title: "Source"; value: root.subscription.source }
            InfoRow { title: "Group"; value: root.subscription.groupName }
            InfoRow { title: "Feed"; value: root.feedLink(root.subscription) }
            InfoRow { title: "Created"; value: root.subscription.createdAt }
            InfoRow { title: "Last Checked"; value: root.subscription.lastCheckedAt }
        }
    }

    CustomDialog {
        id: removeDialog
        objectName: "removeSubscriptionDialog"
        title: "Remove subscription?"
        modal: true
        parent: QQC.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(440, root.width - 40)
        standardButtons: QQC.Dialog.NoButton

        ColumnLayout {
            anchors.fill: parent
            spacing: 16
            CustomLabel {
                text: "\"" + root.clean(root.subscription.title) + "\" will stop updating. Processed transcripts stay in the library."
                color: Theme.textColor
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                spacing: 8
                Item { Layout.fillWidth: true }
                CustomButton {
                    text: "Cancel"
                    onClicked: removeDialog.close()
                }
                CustomButton {
                    objectName: "confirmRemoveSubscription"
                    text: "Remove"
                    highlighted: true
                    onClicked: {
                        root.jobs.removeSubscription(root.subscription.id);
                        removeDialog.close();
                    }
                }
            }
        }
    }

    CustomDialog {
        id: episodeDialog
        objectName: "subscriptionEpisodeDialog"
        readonly property var item: root.presentedEpisode || ({})
        title: root.clean(item.title)
        modal: true
        parent: QQC.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(620, root.width - 40)
        height: Math.min(560, parent.height - 60)
        standardButtons: QQC.Dialog.NoButton
        onClosed: root.presentedEpisode = null

        ColumnLayout {
            anchors.fill: parent
            spacing: 14

            RowLayout {
                spacing: 8
                Pill {
                    text: episodeDialog.item.hasProcessed ? "Processed" : "Unprocessed"
                    tint: episodeDialog.item.hasProcessed ? Theme.successColor : Theme.highlightColor
                }
                Pill {
                    text: root.queueTitle(episodeDialog.item.queueStatus)
                    tint: Theme.placeholderTextColor
                }
                CustomLabel {
                    text: root.clean(episodeDialog.item.seriesName)
                    color: Theme.placeholderTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            CustomScrollView {
                id: episodeScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: episodeScroll.availableWidth
                    spacing: 18

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: metadataGrid.implicitHeight + 28
                        radius: 8
                        color: Theme.alternateBaseColor
                        ColumnLayout {
                            id: metadataGrid
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 9
                            InfoRow { title: "Channel"; value: episodeDialog.item.seriesName; hidesEmpty: true }
                            InfoRow { title: "Source"; value: episodeDialog.item.source; hidesEmpty: true }
                            InfoRow { title: "Published"; value: episodeDialog.item.publishedAt; hidesEmpty: true }
                            InfoRow { title: "Duration"; value: episodeDialog.item.duration; hidesEmpty: true }
                            InfoRow { title: "Episode Link"; value: episodeDialog.item.sourceURL; hidesEmpty: true }
                            InfoRow { title: "Feed"; value: episodeDialog.item.seriesURL; hidesEmpty: true }
                            InfoRow { title: "Audio"; value: episodeDialog.item.mediaURL; hidesEmpty: true }
                        }
                    }

                    CustomLabel {
                        text: "Description"
                        color: Theme.textColor
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    CustomLabel {
                        text: root.clean(episodeDialog.item.description) || "No description from feed."
                        color: root.clean(episodeDialog.item.description) ? Theme.textColor : Theme.placeholderTextColor
                        wrapMode: Text.Wrap
                        lineHeight: 1.2
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                spacing: 8
                CustomButton {
                    text: "Copy Link"
                    enabled: root.clean(episodeDialog.item.sourceURL || episodeDialog.item.mediaURL).length > 0
                    onClicked: root.copyText(root.clean(episodeDialog.item.sourceURL || episodeDialog.item.mediaURL))
                }
                Item { Layout.fillWidth: true }
                CustomButton {
                    text: "Close"
                    onClicked: episodeDialog.close()
                }
                CustomButton {
                    objectName: "openEpisodeInLibrary"
                    visible: episodeDialog.item.hasProcessed === true
                    text: "Open in Library"
                    highlighted: true
                    onClicked: root.openInLibrary(episodeDialog.item)
                }
            }
        }
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.dividerColor
    }

    component Placeholder: Item {
        id: placeholder
        property string title
        property string message
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 44, 420)
            spacing: 8
            CustomLabel {
                text: placeholder.title
                color: Theme.textColor
                font.pixelSize: 18
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
            CustomLabel {
                text: placeholder.message
                color: Theme.placeholderTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }

    component SelectionButton: CustomButton {
        id: selectionButton
        implicitWidth: 36
        font.pixelSize: 17
        background: Rectangle {
            radius: 8
            color: selectionButton.down ? Theme.buttonPressedColor : selectionButton.hovered ? Theme.buttonHoveredColor : "transparent"
            border.width: selectionButton.visualFocus ? 2 : 0
            border.color: Theme.accentColor
        }
    }

    component MenuEntry: CustomMenuItem {
        implicitHeight: visible ? Math.max(38, Fonts.listItemHeight) : 0
    }

    component StatusFilterEntry: MenuEntry {
        property int index
        readonly property var filter: root.statusFilters[index]
        text: (root.statusFilter === filter.id ? "✓  " : "     ") + filter.title + " " + root.counts[filter.id]
        onTriggered: root.statusFilter = filter.id
    }

    component TimeFilterEntry: MenuEntry {
        property int index
        readonly property var filter: root.timeFilters[index]
        text: (root.timeFilter === filter.id ? "✓  " : "     ") + filter.title
        onTriggered: root.timeFilter = filter.id
    }

    component Pill: CustomLabel {
        property color tint: Theme.placeholderTextColor
        color: tint
        font.pixelSize: 11
        font.weight: Font.DemiBold
        leftPadding: 9
        rightPadding: 9
        topPadding: 4
        bottomPadding: 4
        background: Rectangle {
            radius: height / 2
            color: Qt.rgba(parent.tint.r, parent.tint.g, parent.tint.b, 0.14)
        }
    }

    component InfoRow: Item {
        id: info
        property string title
        property var value
        property bool hidesEmpty: false
        readonly property string text: root.clean(value)
        visible: !hidesEmpty || text.length > 0
        Layout.fillWidth: true
        implicitHeight: visible ? valueLabel.implicitHeight : 0
        CustomLabel {
            text: info.title
            color: Theme.placeholderTextColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            width: 92
        }
        CustomLabel {
            id: valueLabel
            x: 104
            width: info.width - 104
            text: info.text.length > 0 ? info.text : "None"
            color: Theme.textColor
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }
}
