import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "Format.js" as Fmt

// One usage window: label + percentage, a slim bar, and (optionally) when it resets.
ColumnLayout {
    id: row

    property var metric
    property bool hero: false          // larger number, for the primary window
    property bool compact: false       // sub-row (e.g. per-model), smaller type
    property bool showReset: true

    readonly property real util: metric && metric.utilization !== null ? metric.utilization : 0
    readonly property color accent: root.levelColor(metric ? metric.utilization : null, root.brand)
    readonly property string resetText: {
        if (!metric || !metric.resetsAt)
            return metric && metric.utilization === 0 ? i18n("Not used yet") : "";
        var rel = Fmt.relative(metric.resetsAt, root.now);
        var s = rel === "now" ? i18n("Resetting now") : i18n("Resets %1", rel);
        if (Plasmoid.configuration.showAbsoluteTime)
            s += "  ·  " + Fmt.absolute(metric.resetsAt, root.now, Qt.locale(), Qt.locale().timeFormat(Locale.ShortFormat));
        return s;
    }

    spacing: Math.round(Kirigami.Units.smallSpacing * (hero ? 1.5 : 1))

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: row.metric ? row.metric.label : ""
            elide: Text.ElideRight
            font.pixelSize: row.compact ? Kirigami.Theme.smallFont.pixelSize : Kirigami.Theme.defaultFont.pixelSize
            opacity: row.compact ? 0.75 : 0.9
            Layout.alignment: Qt.AlignBaseline
        }
        PlasmaComponents.Label {
            text: Fmt.pct(row.metric ? row.metric.utilization : null)
            font.features: { "tnum": 1 }
            font.weight: row.hero ? Font.DemiBold : Font.Medium
            font.pixelSize: row.hero ? Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.9)
                          : row.compact ? Kirigami.Theme.smallFont.pixelSize
                          : Kirigami.Theme.defaultFont.pixelSize
            color: root.levelColor(row.metric ? row.metric.utilization : null, Kirigami.Theme.textColor)
            Layout.alignment: Qt.AlignBaseline
        }
    }

    UsageBar {
        Layout.fillWidth: true
        value: row.util
        color: row.accent
        implicitHeight: Math.round(Kirigami.Units.gridUnit * (row.hero ? 0.4 : row.compact ? 0.22 : 0.3))
    }

    PlasmaComponents.Label {
        visible: row.showReset && text !== ""
        Layout.fillWidth: true
        text: row.resetText
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        font.features: { "tnum": 1 }
        opacity: 0.6
        elide: Text.ElideRight
    }
}
