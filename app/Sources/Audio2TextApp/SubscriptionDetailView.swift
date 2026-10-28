import AppKit
import SwiftUI
#if canImport(Audio2TextCore)
    import Audio2TextCore
#endif

struct SubscriptionDetailViewState: Equatable {
    let snapshot: SubscriptionDetailSnapshot?
    let snapshotVersion: Int
    let hasSubscriptions: Bool
    let subscriptionCount: Int
    let isAddingSubscription: Bool
    let isRefreshingSubscriptions: Bool
    let isProcessing: Bool
    let isCloudSummaryConfigured: Bool

    static func == (lhs: SubscriptionDetailViewState, rhs: SubscriptionDetailViewState) -> Bool {
        lhs.snapshotVersion == rhs.snapshotVersion
            && lhs.snapshot?.subscription.id == rhs.snapshot?.subscription.id
            && lhs.hasSubscriptions == rhs.hasSubscriptions
            && lhs.subscriptionCount == rhs.subscriptionCount
            && lhs.isAddingSubscription == rhs.isAddingSubscription
            && lhs.isRefreshingSubscriptions == rhs.isRefreshingSubscriptions
            && lhs.isProcessing == rhs.isProcessing
            && lhs.isCloudSummaryConfigured == rhs.isCloudSummaryConfigured
    }

    var isSubscriptionBusy: Bool {
        isRefreshingSubscriptions || isAddingSubscription || isProcessing
    }
}

struct SubscriptionDetailView: View, Equatable {
    let controller: JobController
    let state: SubscriptionDetailViewState
    @State private var presentedEpisode: ProcessLibraryItem?
    @State private var selectedEpisodeIDs: Set<String> = []
    @State private var pendingDeleteItems: [ProcessLibraryItem] = []
    @State private var pendingRemoval: PodcastSubscriptionItem?
    @State private var showsSubscriptionInfo = false
    @State private var episodeStatusFilter: SubscriptionEpisodeStatusFilter = .all
    @State private var episodeTimeFilter: SubscriptionEpisodeTimeFilter = .all
    @State private var episodeSortOrder: SubscriptionEpisodeSortOrder = .newestFirst

    static func == (lhs: SubscriptionDetailView, rhs: SubscriptionDetailView) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(snapshot: state.snapshot)
            Divider()
            if let snapshot = state.snapshot {
                if snapshot.episodes.isEmpty {
                    SubscriptionPlaceholder(
                        systemImage: "tray",
                        title: "No episodes yet",
                        message: "Refresh the subscription to import its latest episodes."
                    )
                } else {
                    episodeToolbar(counts: snapshot.counts)
                    Divider()
                    SubscriptionEpisodeList(
                        snapshotVersion: state.snapshotVersion,
                        episodes: filteredEpisodes,
                        selectedEpisodeIDs: selectedEpisodeIDs,
                        open: presentEpisode,
                        openInLibrary: openInLibrary,
                        toggleSelection: toggleEpisodeSelection
                    )
                    .equatable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if state.hasSubscriptions {
                SubscriptionPlaceholder(
                    systemImage: "dot.radiowaves.left.and.right",
                    title: "Select a subscription",
                    message: "Choose a subscription in the sidebar to browse its episodes."
                )
            } else {
                SubscriptionPlaceholder(
                    systemImage: "dot.radiowaves.left.and.right",
                    title: "No subscriptions",
                    message: "Add a podcast or RSS feed to create metadata-only episode records."
                )
            }
        }
        .sheet(item: $presentedEpisode) { item in
            SubscriptionEpisodeInfoSheet(
                item: item,
                details: ProcessLibrary.channelEpisodeDetails(for: item),
                openInLibrary: item.isProcessed ? { openInLibrary(item) } : nil
            )
        }
        .alert("Delete selected items?", isPresented: deleteConfirmationBinding) {
            Button("Cancel", role: .cancel) {
                pendingDeleteItems = []
            }
            Button("Delete \(pendingDeleteItems.count) items", role: .destructive) {
                let items = pendingDeleteItems
                controller.deleteLibraryItems(items)
                clearEpisodeSelection()
                pendingDeleteItems = []
            }
        } message: {
            Text("This deletes the selected items' cached files and outputs. Subscription items will not reappear after refresh.")
        }
        .onChange(of: state.snapshot?.subscription.id) { _ in
            clearEpisodeSelection()
        }
        .onChange(of: state.snapshotVersion) { _ in
            reconcileEpisodeSelection()
        }
        .onChange(of: episodeStatusFilter) { _ in
            reconcileEpisodeSelection()
        }
        .onChange(of: episodeTimeFilter) { _ in
            reconcileEpisodeSelection()
        }
    }

    // MARK: Header

    private func header(snapshot: SubscriptionDetailSnapshot?) -> some View {
        HStack(alignment: .center, spacing: AppControlMetrics.controlSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot?.subscription.title ?? "Subscriptions")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(headerSubtitle(snapshot: snapshot))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppControlMetrics.controlSpacing)
            if let subscription = snapshot?.subscription {
                Button {
                    controller.refreshSubscription(subscription)
                } label: {
                    if state.isRefreshingSubscriptions {
                        Label {
                            Text("Refreshing")
                        } icon: {
                            AppProgressSpinner()
                        }
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(AppButtonStyle())
                .disabled(state.isSubscriptionBusy)
                .appFastTooltip("Check the feed for new episodes")

                subscriptionMenu(subscription)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .sheet(isPresented: $showsSubscriptionInfo) {
            if let subscription = snapshot?.subscription {
                SubscriptionInfoSheet(subscription: subscription, counts: snapshot?.counts)
            }
        }
        .alert("Remove subscription?", isPresented: removalConfirmationBinding) {
            Button("Cancel", role: .cancel) {
                pendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                if let subscription = pendingRemoval {
                    controller.removeSubscription(subscription)
                }
                pendingRemoval = nil
            }
        } message: {
            Text("\"\(pendingRemoval?.title ?? "")\" will stop updating. Processed transcripts stay in the library.")
        }
    }

    private func subscriptionMenu(_ subscription: PodcastSubscriptionItem) -> some View {
        AppMenu(iconOnly: true) {
            Button {
                showsSubscriptionInfo = true
            } label: {
                Label("Subscription Info", systemImage: "info.circle")
            }
            Button {
                copySubscriptionURLToPasteboard(subscription)
            } label: {
                Label("Copy Feed Link", systemImage: "link")
            }
            .disabled(SubscriptionFeedURL.display(for: subscription) == nil)
            Divider()
            Button {
                controller.fetchSubscriptionHistory(subscription)
            } label: {
                Label("Fetch Complete History", systemImage: "clock.arrow.circlepath")
            }
            .disabled(state.isSubscriptionBusy)
            Divider()
            Button(role: .destructive) {
                pendingRemoval = subscription
            } label: {
                Label("Remove Subscription…", systemImage: "trash")
            }
            .disabled(state.isSubscriptionBusy)
        } label: {
            Image(systemName: "ellipsis")
        }
        .appFastTooltip("More actions")
        .accessibilityLabel("More subscription actions")
    }

    private func headerSubtitle(snapshot: SubscriptionDetailSnapshot?) -> String {
        guard let snapshot else {
            return state.hasSubscriptions ? "\(state.subscriptionCount) subscriptions" : "No subscriptions yet"
        }
        var parts = ["\(snapshot.counts.total) episodes", "\(snapshot.counts.processed) processed"]
        if let checkedAt = LibraryDateParser.date(from: snapshot.subscription.lastCheckedAt) {
            parts.append("Checked \(checkedAt.formatted(.relative(presentation: .named)))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Episode toolbar

    // The filter and selection toolbars share one slot with a fixed height, so
    // selecting an episode never pushes the list content down.
    private func episodeToolbar(counts: SubscriptionDetailCounts) -> some View {
        HStack(spacing: AppControlMetrics.controlSpacing) {
            selectionMenu
            if bulkActionState.hasSelection {
                SubscriptionBulkActionBar(
                    actionState: bulkActionState,
                    clearSelection: clearEpisodeSelection,
                    processSelection: processSelectedEpisodes,
                    archiveSelection: archiveSelectedEpisodes,
                    deleteSelection: requestDeleteSelectedEpisodes
                )
            } else {
                SubscriptionEpisodeFilterBar(
                    counts: counts,
                    statusFilter: $episodeStatusFilter,
                    timeFilter: $episodeTimeFilter,
                    sortOrder: $episodeSortOrder
                )
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: AppControlMetrics.toolbarHeight + AppControlMetrics.controlSpacing)
    }

    private var selectionMenu: some View {
        AppMenu(iconOnly: true) {
            Button {
                selectedEpisodeIDs = Set(filteredEpisodes.map(\.id))
            } label: {
                Label("Select All (\(filteredEpisodes.count))", systemImage: "checkmark.circle")
            }
            .disabled(filteredEpisodes.isEmpty || isAllVisibleSelected)
            Button {
                selectFrontVisibleEpisodeSelection(10)
            } label: {
                Label("Select First 10", systemImage: "list.number")
            }
            .disabled(filteredEpisodes.isEmpty)
            Divider()
            Button {
                clearEpisodeSelection()
            } label: {
                Label("Deselect All", systemImage: "xmark.circle")
            }
            .disabled(selectedEpisodeIDs.isEmpty)
        } label: {
            Image(systemName: selectionSymbol)
                .foregroundStyle(selectedEpisodeIDs.isEmpty ? Color.secondary : Color.accentColor)
        }
        .appFastTooltip("Select episodes")
        .accessibilityLabel("Select episodes")
        .accessibilityValue("\(bulkActionState.selectedCount) selected")
    }

    private var isAllVisibleSelected: Bool {
        !filteredEpisodes.isEmpty && bulkActionState.selectedCount == filteredEpisodes.count
    }

    private var selectionSymbol: String {
        if selectedEpisodeIDs.isEmpty { return "circle" }
        return isAllVisibleSelected ? "checkmark.circle.fill" : "minus.circle.fill"
    }

    // MARK: Episode state

    private func presentEpisode(_ item: ProcessLibraryItem) {
        presentedEpisode = item
    }

    private func openInLibrary(_ item: ProcessLibraryItem) {
        presentedEpisode = nil
        controller.openProcessedSubscriptionItem(item)
    }

    private var currentEpisodes: [SubscriptionEpisodeDisplayItem] {
        state.snapshot?.episodes ?? []
    }

    private var filteredEpisodes: [SubscriptionEpisodeDisplayItem] {
        SubscriptionEpisodeFilters.filteredEpisodes(
            currentEpisodes,
            statusFilter: episodeStatusFilter,
            timeFilter: episodeTimeFilter,
            sortOrder: episodeSortOrder
        )
    }

    private var selectedItems: [ProcessLibraryItem] {
        SubscriptionBulkSelection.selectedItems(
            from: filteredEpisodes,
            selectedIDs: selectedEpisodeIDs
        )
    }

    private var bulkActionState: SubscriptionBulkActionState {
        let items = selectedItems
        return SubscriptionBulkActionState(
            selectedCount: items.count,
            transcribeAndSummarizeCount: processableSelectedItems(workflow: .transcribeAndSummarize).count,
            localOnlyCount: processableSelectedItems(workflow: .localOnly).count,
            isProcessing: state.isProcessing,
            isCloudSummaryConfigured: state.isCloudSummaryConfigured
        )
    }

    private func processableSelectedItems(workflow: ProcessingWorkflow) -> [ProcessLibraryItem] {
        SubscriptionBulkSelection.processableItems(from: selectedItems) { item in
            controller.canProcessLibraryItem(item, workflow: workflow)
        }
    }

    private func toggleEpisodeSelection(_ item: ProcessLibraryItem) {
        if selectedEpisodeIDs.contains(item.id) {
            selectedEpisodeIDs.remove(item.id)
        } else {
            selectedEpisodeIDs.insert(item.id)
        }
    }

    private func selectFrontVisibleEpisodeSelection(_ limit: Int) {
        selectedEpisodeIDs = SubscriptionBulkSelection.frontVisibleSelection(
            episodes: filteredEpisodes,
            limit: limit
        )
    }

    private func clearEpisodeSelection() {
        selectedEpisodeIDs.removeAll()
    }

    private func reconcileEpisodeSelection() {
        selectedEpisodeIDs = SubscriptionBulkSelection.reconciledSelection(
            selectedEpisodeIDs,
            episodes: filteredEpisodes
        )
    }

    private func processSelectedEpisodes(workflow: ProcessingWorkflow) {
        let items = processableSelectedItems(workflow: workflow)
        guard !items.isEmpty else { return }
        controller.processLibraryItems(items, workflow: workflow)
        clearEpisodeSelection()
    }

    private func archiveSelectedEpisodes() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        controller.archiveLibraryItems(items)
        clearEpisodeSelection()
    }

    private func requestDeleteSelectedEpisodes() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        pendingDeleteItems = items
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { !pendingDeleteItems.isEmpty },
            set: { if !$0 { pendingDeleteItems = [] } }
        )
    }

    private var removalConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        )
    }

    private func copySubscriptionURLToPasteboard(_ subscription: PodcastSubscriptionItem) {
        guard let url = SubscriptionFeedURL.display(for: subscription) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }
}

private enum SubscriptionFeedURL {
    static func display(for subscription: PodcastSubscriptionItem) -> String? {
        let feedURL = subscription.feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !feedURL.isEmpty { return feedURL }
        let url = subscription.url.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }
}

private struct SubscriptionPlaceholder: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SubscriptionEpisodeList: View, Equatable {
    let snapshotVersion: Int
    let episodes: [SubscriptionEpisodeDisplayItem]
    let selectedEpisodeIDs: Set<String>
    let open: (ProcessLibraryItem) -> Void
    let openInLibrary: (ProcessLibraryItem) -> Void
    let toggleSelection: (ProcessLibraryItem) -> Void

    static func == (lhs: SubscriptionEpisodeList, rhs: SubscriptionEpisodeList) -> Bool {
        lhs.snapshotVersion == rhs.snapshotVersion
            && lhs.episodes == rhs.episodes
            && lhs.selectedEpisodeIDs == rhs.selectedEpisodeIDs
    }

    var body: some View {
        if episodes.isEmpty {
            SubscriptionPlaceholder(
                systemImage: "line.3.horizontal.decrease.circle",
                title: "No matching episodes",
                message: "Change the status or time range filters to see more episodes."
            )
        } else {
            List {
                ForEach(episodes) { episode in
                    SubscriptionEpisodeRow(
                        episode: episode,
                        isSelected: selectedEpisodeIDs.contains(episode.id),
                        open: open,
                        openInLibrary: openInLibrary,
                        toggleSelection: toggleSelection
                    )
                    .equatable()
                    .listRowInsets(EdgeInsets(top: 1, leading: 14, bottom: 1, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct SubscriptionDetailSnapshot: Equatable {
    let subscription: PodcastSubscriptionItem
    let counts: SubscriptionDetailCounts
    let episodes: [SubscriptionEpisodeDisplayItem]

    init(subscription: PodcastSubscriptionItem, items: [ProcessLibraryItem]) {
        self.subscription = subscription
        let unprocessedCount = items.reduce(into: 0) { count, item in
            if !item.isProcessed {
                count += 1
            }
        }
        counts = SubscriptionDetailCounts(
            unprocessed: unprocessedCount,
            total: items.count
        )
        episodes = items.map(SubscriptionEpisodeDisplayItem.init)
    }
}

struct SubscriptionDetailCounts: Equatable {
    let unprocessed: Int
    let total: Int

    var processed: Int {
        max(total - unprocessed, 0)
    }

    var asSubscriptionItemCounts: SubscriptionItemCounts {
        SubscriptionItemCounts(unprocessed: unprocessed, total: total)
    }
}

enum SubscriptionEpisodeStatusFilter: String, CaseIterable, Identifiable {
    case all
    case unprocessed
    case processed

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all: return "All"
        case .unprocessed: return "Unprocessed"
        case .processed: return "Processed"
        }
    }

    func count(in counts: SubscriptionDetailCounts) -> Int {
        switch self {
        case .all: return counts.total
        case .unprocessed: return counts.unprocessed
        case .processed: return counts.processed
        }
    }

    func includes(_ episode: SubscriptionEpisodeDisplayItem) -> Bool {
        switch self {
        case .all: return true
        case .unprocessed: return !episode.isProcessed
        case .processed: return episode.isProcessed
        }
    }
}

enum SubscriptionEpisodeTimeFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case last7Days
    case last30Days
    case last90Days
    case thisYear

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all: return "All time"
        case .today: return "Today"
        case .last7Days: return "Last 7 days"
        case .last30Days: return "Last 30 days"
        case .last90Days: return "Last 90 days"
        case .thisYear: return "This year"
        }
    }

    func includes(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .last7Days:
            return date >= startDate(daysIncludingToday: 7, now: now, calendar: calendar)
        case .last30Days:
            return date >= startDate(daysIncludingToday: 30, now: now, calendar: calendar)
        case .last90Days:
            return date >= startDate(daysIncludingToday: 90, now: now, calendar: calendar)
        case .thisYear:
            return calendar.component(.year, from: date) == calendar.component(.year, from: now)
        }
    }

    private func startDate(daysIncludingToday: Int, now: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(daysIncludingToday - 1), to: startOfToday) ?? startOfToday
    }
}

enum SubscriptionEpisodeSortOrder: Equatable {
    case oldestFirst
    case newestFirst

    var title: String {
        self == .oldestFirst ? "Oldest first" : "Newest first"
    }

    var systemImage: String {
        self == .oldestFirst ? "arrow.up" : "arrow.down"
    }

    var toggled: Self {
        self == .oldestFirst ? .newestFirst : .oldestFirst
    }
}

enum SubscriptionEpisodeFilters {
    static func filteredEpisodes(
        _ episodes: [SubscriptionEpisodeDisplayItem],
        statusFilter: SubscriptionEpisodeStatusFilter,
        timeFilter: SubscriptionEpisodeTimeFilter,
        sortOrder: SubscriptionEpisodeSortOrder = .newestFirst,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SubscriptionEpisodeDisplayItem] {
        episodes.filter { episode in
            statusFilter.includes(episode)
                && timeFilter.includes(episode.filterDate, now: now, calendar: calendar)
        }.sorted { lhs, rhs in
            if lhs.filterDate == rhs.filterDate {
                return lhs.id < rhs.id
            }
            return sortOrder == .oldestFirst
                ? lhs.filterDate < rhs.filterDate
                : lhs.filterDate > rhs.filterDate
        }
    }
}

private struct SubscriptionEpisodeFilterBar: View {
    let counts: SubscriptionDetailCounts
    @Binding var statusFilter: SubscriptionEpisodeStatusFilter
    @Binding var timeFilter: SubscriptionEpisodeTimeFilter
    @Binding var sortOrder: SubscriptionEpisodeSortOrder

    var body: some View {
        HStack(spacing: AppControlMetrics.controlSpacing) {
            // Drop the counts before the trailing controls run out of room.
            ViewThatFits(in: .horizontal) {
                statusPicker(showsCounts: true)
                statusPicker(showsCounts: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppControlMetrics.controlSpacing) {
                timeFilterMenu

                Button {
                    sortOrder = sortOrder.toggled
                } label: {
                    Image(systemName: sortOrder.systemImage)
                }
                .buttonStyle(AppButtonStyle(iconOnly: true))
                .appFastTooltip(sortOrder.title)
                .accessibilityLabel("Sort by publication date")
                .accessibilityValue(sortOrder.title)
            }
            .fixedSize()
            .layoutPriority(1)
        }
    }

    private func statusPicker(showsCounts: Bool) -> some View {
        AppPicker("Episode status", selection: $statusFilter) {
            ForEach(SubscriptionEpisodeStatusFilter.allCases) { filter in
                Text(showsCounts ? "\(filter.title) \(filter.count(in: counts))" : filter.title).tag(filter)
            }
        }
        .appSegmentedControl(size: .regular)
        .labelsHidden()
        .fixedSize()
    }

    private var timeFilterMenu: some View {
        AppMenu(iconOnly: timeFilter == .all, variant: timeFilter == .all ? .normal : .prominent) {
            ForEach(SubscriptionEpisodeTimeFilter.allCases) { filter in
                Button {
                    timeFilter = filter
                } label: {
                    if timeFilter == filter {
                        Label(filter.title, systemImage: "checkmark")
                    } else {
                        Text(filter.title)
                    }
                }
            }
        } label: {
            if timeFilter == .all {
                Image(systemName: "calendar")
            } else {
                AppMenuLabel(title: timeFilter.title, systemImage: "calendar")
            }
        }
        .appFastTooltip("Publication date: \(timeFilter.title.lowercased())")
        .accessibilityLabel("Episode time range")
        .accessibilityValue(timeFilter.title)
    }
}

enum SubscriptionBulkSelection {
    static func selectedItems(
        from episodes: [SubscriptionEpisodeDisplayItem],
        selectedIDs: Set<String>
    ) -> [ProcessLibraryItem] {
        episodes
            .filter { selectedIDs.contains($0.id) }
            .map(\.item)
    }

    static func unprocessedItems(from items: [ProcessLibraryItem]) -> [ProcessLibraryItem] {
        items.filter { !$0.isProcessed }
    }

    static func processableItems(
        from items: [ProcessLibraryItem],
        canProcess: (ProcessLibraryItem) -> Bool
    ) -> [ProcessLibraryItem] {
        unprocessedItems(from: items).filter(canProcess)
    }

    static func reconciledSelection(
        _ selectedIDs: Set<String>,
        episodes: [SubscriptionEpisodeDisplayItem]
    ) -> Set<String> {
        selectedIDs.intersection(Set(episodes.map(\.id)))
    }

    static func toggledVisibleSelection(
        _ selectedIDs: Set<String>,
        episodes: [SubscriptionEpisodeDisplayItem]
    ) -> Set<String> {
        let visibleIDs = Set(episodes.map(\.id))
        guard !visibleIDs.isEmpty else { return [] }
        let selectedVisibleIDs = selectedIDs.intersection(visibleIDs)
        return selectedVisibleIDs.count == visibleIDs.count ? [] : visibleIDs
    }

    static func frontVisibleSelection(
        episodes: [SubscriptionEpisodeDisplayItem],
        limit: Int
    ) -> Set<String> {
        guard limit > 0 else { return [] }
        return Set(episodes.prefix(limit).map(\.id))
    }
}

struct SubscriptionBulkActionState: Equatable {
    let selectedCount: Int
    let transcribeAndSummarizeCount: Int
    let localOnlyCount: Int
    let isProcessing: Bool
    let isCloudSummaryConfigured: Bool

    var hasSelection: Bool {
        selectedCount > 0
    }

    var canProcessAny: Bool {
        transcribeAndSummarizeCount > 0 || localOnlyCount > 0
    }
}

private struct SubscriptionBulkActionBar: View {
    let actionState: SubscriptionBulkActionState
    let clearSelection: () -> Void
    let processSelection: (ProcessingWorkflow) -> Void
    let archiveSelection: () -> Void
    let deleteSelection: () -> Void

    var body: some View {
        HStack(spacing: AppControlMetrics.controlSpacing) {
            Text("\(actionState.selectedCount) selected")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)

            Spacer(minLength: 0)

            AppMenu(variant: .prominent) {
                Button {
                    processSelection(.transcribeAndSummarize)
                } label: {
                    Label(
                        ProcessingWorkflow.transcribeAndSummarize.actionTitle(isCloudConfigured: actionState.isCloudSummaryConfigured),
                        systemImage: "play.fill"
                    )
                }
                .disabled(actionState.isProcessing || actionState.transcribeAndSummarizeCount == 0)

                Button {
                    processSelection(.localOnly)
                } label: {
                    Label("Transcribe locally", systemImage: "waveform")
                }
                .disabled(actionState.isProcessing || actionState.localOnlyCount == 0)
            } label: {
                AppMenuLabel(title: "Process", systemImage: "play.fill")
            }
            .disabled(actionState.isProcessing || !actionState.canProcessAny)

            Button {
                archiveSelection()
            } label: {
                Image(systemName: "archivebox")
            }
            .buttonStyle(AppButtonStyle(iconOnly: true))
            .disabled(actionState.isProcessing)
            .appFastTooltip("Archive selected")
            .accessibilityLabel("Archive selected")

            Button(role: .destructive) {
                deleteSelection()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(AppButtonStyle(iconOnly: true))
            .disabled(actionState.isProcessing)
            .appFastTooltip("Delete selected")
            .accessibilityLabel("Delete selected")

            Button {
                clearSelection()
            } label: {
                Text("Done")
                    .lineLimit(1)
            }
            .buttonStyle(AppButtonStyle(variant: .subtle))
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Deselect all")
        }
    }
}

struct SubscriptionEpisodeDisplayItem: Identifiable, Equatable {
    let item: ProcessLibraryItem
    let title: String
    let primaryCaption: String
    let queueTitle: String
    let dateTitle: String
    let filterDate: Date
    let iconName: String
    let isProcessed: Bool
    let isStarred: Bool
    let iconColor: Color
    let accessibilityLabel: String

    var id: String {
        item.id
    }

    static func == (lhs: SubscriptionEpisodeDisplayItem, rhs: SubscriptionEpisodeDisplayItem) -> Bool {
        lhs.item == rhs.item
            && lhs.title == rhs.title
            && lhs.primaryCaption == rhs.primaryCaption
            && lhs.queueTitle == rhs.queueTitle
            && lhs.dateTitle == rhs.dateTitle
            && lhs.filterDate == rhs.filterDate
            && lhs.iconName == rhs.iconName
            && lhs.isProcessed == rhs.isProcessed
            && lhs.isStarred == rhs.isStarred
            && lhs.accessibilityLabel == rhs.accessibilityLabel
    }

    init(item: ProcessLibraryItem) {
        self.item = item
        title = item.title
        primaryCaption = Self.primaryCaption(for: item)
        queueTitle = item.queueStatus.compactTitle
        let displayDate = Self.publishedDate(for: item) ?? item.modifiedAt
        filterDate = displayDate
        dateTitle = displayDate.formatted(date: .abbreviated, time: .omitted)
        iconName = item.isProcessed ? "doc.text.fill" : "waveform"
        isProcessed = item.isProcessed
        isStarred = item.isStarred
        iconColor = item.isProcessed ? .green : .secondary
        accessibilityLabel = "Show episode details for \(item.title)"
    }

    private static func primaryCaption(for item: ProcessLibraryItem) -> String {
        let originalTitle = item.originalTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !originalTitle.isEmpty && originalTitle != title {
            return "Original title: \(originalTitle)"
        }
        return item.status
    }

    private static func publishedDate(for item: ProcessLibraryItem) -> Date? {
        LibraryDateParser.date(from: item.publishedAt)
    }
}

// Clicking a row always shows its details in place. Leaving the subscription
// page only happens through the explicit "Open" action on processed episodes.
private struct SubscriptionEpisodeRow: View, Equatable {
    let episode: SubscriptionEpisodeDisplayItem
    let isSelected: Bool
    let open: (ProcessLibraryItem) -> Void
    let openInLibrary: (ProcessLibraryItem) -> Void
    let toggleSelection: (ProcessLibraryItem) -> Void

    static func == (lhs: SubscriptionEpisodeRow, rhs: SubscriptionEpisodeRow) -> Bool {
        lhs.episode == rhs.episode
            && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppControlMetrics.controlSpacing) {
            AppSelectionButton(
                isSelected: isSelected,
                label: isSelected ? "Deselect \(episode.title)" : "Select \(episode.title)"
            ) {
                toggleSelection(episode.item)
            }

            Button {
                open(episode.item)
            } label: {
                rowContent
            }
            .buttonStyle(AppRowButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(episode.accessibilityLabel)

            if episode.isProcessed {
                Button {
                    openInLibrary(episode.item)
                } label: {
                    Text("Open")
                }
                .buttonStyle(AppButtonStyle(size: .compact))
                .appFastTooltip("Open transcript in Library")
                .accessibilityLabel("Open \(episode.title) in Library")
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, AppControlMetrics.controlSpacing)
        .frame(
            maxWidth: .infinity,
            minHeight: AppControlMetrics.episodeRowHeight,
            maxHeight: AppControlMetrics.episodeRowHeight,
            alignment: .leading
        )
        .appRowSurface(isSelected: isSelected)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: AppControlMetrics.controlSpacing) {
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 5) {
                    Image(systemName: episode.iconName)
                        .foregroundStyle(episode.iconColor)
                        .accessibilityHidden(true)
                    Text(episode.dateTitle)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("·")
                    Text(episode.primaryCaption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("·")
                    Text(episode.queueTitle)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
            if episode.isStarred {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Starred")
            }
        }
        .contentShape(Rectangle())
    }
}

private struct SubscriptionInfoSheet: View {
    let subscription: PodcastSubscriptionItem
    let counts: SubscriptionDetailCounts?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(subscription.title)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .padding(22)
            Divider()
            VStack(alignment: .leading, spacing: 9) {
                if let counts {
                    infoRow("Episodes", "\(counts.total) total · \(counts.unprocessed) unprocessed · \(counts.processed) processed")
                }
                infoRow("Source", subscription.source)
                infoRow("Group", subscription.groupName)
                infoRow("Feed", SubscriptionFeedURL.display(for: subscription) ?? "None")
                infoRow("Created", subscription.createdAt)
                infoRow("Last Checked", subscription.lastCheckedAt)
            }
            .textSelection(.enabled)
            .padding(22)
            Spacer(minLength: 0)
            Divider()
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
                .buttonStyle(AppButtonStyle(variant: .prominent))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 460, idealWidth: 520, maxWidth: 640, minHeight: 300)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(trimmed.isEmpty ? "None" : trimmed)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}

private struct SubscriptionEpisodeInfoSheet: View {
    let item: ProcessLibraryItem
    let details: ChannelEpisodeDetails
    let openInLibrary: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(22)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    metadataGrid
                    descriptionSection
                }
                .padding(22)
            }
            Divider()
            footer
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
        }
        .frame(minWidth: 520, idealWidth: 620, maxWidth: 720, minHeight: 420, idealHeight: 560)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            coverImage
            VStack(alignment: .leading, spacing: 7) {
                Text(details.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(3)
                    .textSelection(.enabled)
                HStack(spacing: AppControlMetrics.controlSpacing) {
                    statusPill(item.isProcessed ? "Processed" : "Unprocessed", tint: item.isProcessed ? .green : .blue)
                    statusPill(item.queueStatus.compactTitle, tint: .secondary)
                }
                if let seriesName = details.seriesName {
                    Text(seriesName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let url = remoteURL(details.imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackCover
                case .empty:
                    AppProgressSpinner()
                @unknown default:
                    fallbackCover
                }
            }
            .frame(width: 92, height: 92)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        Image(systemName: "dot.radiowaves.left.and.right")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 92, height: 92)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
    }

    private func statusPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var metadataGrid: some View {
        VStack(alignment: .leading, spacing: 9) {
            detailRow("Channel", details.seriesName)
            detailRow("Source", details.sourceName)
            detailRow("Published", details.publishedAt)
            detailRow("Duration", details.duration)
            detailRow("Episode Link", details.sourceURL)
            detailRow("Feed", details.seriesURL)
            detailRow("Audio", details.audioURL)
            detailRow("GUID", details.guid)
        }
        .textSelection(.enabled)
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
    }

    @ViewBuilder
    private func detailRow(_ title: String, _ value: String?) -> some View {
        if let value = clean(value) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .leading)
                Text(value)
                    .font(.callout)
                    .lineLimit(3)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Description")
                .font(.headline)
            Text(clean(details.description) ?? "No description from feed.")
                .font(.callout)
                .foregroundStyle(clean(details.description) == nil ? .secondary : .primary)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
    }

    private var footer: some View {
        HStack(spacing: AppControlMetrics.controlSpacing) {
            Button {
                copyPrimaryURLToPasteboard()
            } label: {
                Label("Copy Link", systemImage: "link")
            }
            .disabled(clean(details.primaryURL) == nil)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .keyboardShortcut(.cancelAction)
            if let openInLibrary {
                Button {
                    openInLibrary()
                } label: {
                    Label("Open in Library", systemImage: "doc.text")
                }
                .buttonStyle(AppButtonStyle(variant: .prominent))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func copyPrimaryURLToPasteboard() {
        guard let url = clean(details.primaryURL) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func remoteURL(_ value: String?) -> URL? {
        guard let text = clean(value), let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }
        return url
    }
}
