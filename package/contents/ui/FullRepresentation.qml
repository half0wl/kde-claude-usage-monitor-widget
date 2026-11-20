import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "Format.js" as Fmt

// Expanded view: everything, ordered from most to least urgent.
// Session (hero) → weekly all-models → per-model → other → extra usage → status.
PlasmaExtras.Representation {
    id: full

    readonly property var cfg: Plasmoid.configuration
    readonly property var session: root.metricByKey("five_hour")
    readonly property var weekly: root.metricByKey("seven_day")
    readonly property var models: root.metrics.filter(m => m.group === "weekly" && m.key !== "seven_day")
    readonly property var others: root.metrics.filter(m => m.group === "other")
    readonly property bool extraVisible: !!(cfg.showExtra && root.extra && root.extra.enabled)

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 10
    Layout.preferredHeight: body.implicitHeight + header.implicitHeight + footer.implicitHeight + Kirigami.Units.largeSpacing * 3
    Layout.maximumHeight: Kirigami.Units.gridUnit * 34

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/claude.svg")
                isMask: full.cfg.monochromeIcon
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            Kirigami.Heading {
                level: 4
                text: i18n("Claude")
                Layout.fillWidth: true
            }
            // Plan badge
            Rectangle {
                visible: root.plan !== ""
                radius: height / 2
                color: Qt.rgba(root.brand.r, root.brand.g, root.brand.b, 0.15)
                implicitHeight: planLabel.implicitHeight + Kirigami.Units.smallSpacing
                implicitWidth: planLabel.implicitWidth + Kirigami.Units.largeSpacing
                PlasmaComponents.Label {
                    id: planLabel
                    anchors.centerIn: parent
                    text: root.plan
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.weight: Font.Medium
                    color: root.brand
                }
            }
            PlasmaComponents.ToolButton {
                id: refreshButton
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Refresh")
                enabled: !root.loading
                onClicked: root.refresh()
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                RotationAnimation on rotation {
                    running: root.loading
                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                    onStopped: refreshButton.rotation = 0
                }
            }
        }
    }

    // Nothing loaded yet: a single calm message instead of empty bars.
    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: !root.hasData
        icon.name: root.error ? "network-disconnect" : "content-loading-symbolic"
        text: root.error || i18n("Loading usage…")
        explanation: root.errorHint
        helpfulAction: root.error ? retryAction : null
        Kirigami.Action {
            id: retryAction
            icon.name: "view-refresh"
            text: i18n("Try again")
            onTriggered: root.refresh()
        }
    }

    PlasmaComponents.ScrollView {
        anchors.fill: parent
        visible: root.hasData
        contentWidth: availableWidth
        PlasmaComponents.ScrollBar.horizontal.policy: PlasmaComponents.ScrollBar.AlwaysOff

        ColumnLayout {
            id: body
            width: parent.width
            spacing: Kirigami.Units.largeSpacing

            Item { implicitHeight: Kirigami.Units.smallSpacing }

            // ---- Session ----
            UsageRow {
                visible: !!(full.cfg.showSession && full.session)
                metric: full.session
                hero: true
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
            }

            // ---- Weekly ----
            SectionTitle {
                text: i18n("Weekly limits")
                visible: !!((full.cfg.showWeekly && full.weekly) || (full.cfg.showModels && full.models.length > 0))
                Layout.topMargin: Kirigami.Units.smallSpacing
            }
            UsageRow {
                visible: !!(full.cfg.showWeekly && full.weekly)
                metric: full.weekly
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
            }
            Repeater {
                model: full.cfg.showModels ? full.models : []
                UsageRow {
                    required property var modelData
                    metric: modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                }
            }

            // ---- Other windows the API may add later ----
            SectionTitle { text: i18n("Other"); visible: full.cfg.showOther && full.others.length > 0 }
            Repeater {
                model: full.cfg.showOther ? full.others : []
                UsageRow {
                    required property var modelData
                    metric: modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                }
            }

            // ---- Extra (pay-as-you-go) usage ----
            SectionTitle { text: i18n("Extra usage"); visible: full.extraVisible }
            UsageRow {
                visible: full.extraVisible
                metric: full.extraVisible ? {
                    label: (root.extra.usedCredits !== null && root.extra.monthlyLimit !== null)
                           ? i18n("%1 of %2 credits", root.extra.usedCredits, root.extra.monthlyLimit)
                           : i18n("This month"),
                    utilization: root.extra.utilization,
                    resetsAt: null
                } : null
                showReset: false
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
            }

            Item { implicitHeight: Kirigami.Units.smallSpacing }
        }
    }

    footer: PlasmaExtras.PlasmoidHeading {
        position: PlasmaComponents.ToolBar.Footer
        visible: root.hasData
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                visible: root.error !== ""
                source: "dialog-warning-symbolic"
                color: Kirigami.Theme.neutralTextColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.error
                      ? i18n("%1 · showing data from %2", root.error, Fmt.ago(root.lastSuccess, root.now))
                      : i18n("Updated %1", Fmt.ago(root.lastSuccess, root.now))
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                opacity: 0.6
                elide: Text.ElideRight
                PlasmaComponents.ToolTip.text: root.errorHint
                PlasmaComponents.ToolTip.visible: root.errorHint !== "" && footerHover.hovered
                HoverHandler { id: footerHover }
            }
            PlasmaComponents.ToolButton {
                icon.name: "internet-web-browser-symbolic"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Open usage page")
                onClicked: Qt.openUrlExternally("https://claude.ai/settings/usage")
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }
}
