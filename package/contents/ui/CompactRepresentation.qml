import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "Format.js" as Fmt

// Panel view: the smallest useful summary. Icon (optionally ringed) + one number.
MouseArea {
    id: compact

    readonly property var cfg: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var metric: root.panelMetric
    readonly property real util: metric && metric.utilization !== null ? metric.utilization : -1
    readonly property bool ring: cfg.panelStyle === "ring"
    readonly property bool showText: cfg.panelShowPercent || !cfg.panelShowIcon
    readonly property string valueText: {
        if (!root.hasData)
            return root.error ? "!" : "–";
        var t = Fmt.pct(metric.utilization);
        if (cfg.panelShowReset) {
            var r = Fmt.short(metric.resetsAt, root.now);
            if (r)
                t += vertical ? "\n" + r : " · " + r;
        }
        return t;
    }

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton)
            root.refresh();
        else
            root.expanded = !root.expanded;
    }

    Layout.minimumWidth: vertical ? -1 : content.implicitWidth
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: vertical ? content.implicitHeight : -1
    Layout.preferredHeight: Layout.minimumHeight

    GridLayout {
        id: content
        anchors.centerIn: parent
        flow: compact.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: Kirigami.Units.smallSpacing

        Item {
            id: iconBox
            visible: compact.cfg.panelShowIcon || compact.ring
            readonly property real side: compact.vertical
                ? Math.min(compact.width, Kirigami.Units.iconSizes.medium)
                : Math.min(compact.height, Kirigami.Units.iconSizes.medium)
            Layout.preferredWidth: side
            Layout.preferredHeight: side
            Layout.alignment: Qt.AlignCenter

            Kirigami.Icon {
                anchors.centerIn: parent
                visible: compact.cfg.panelShowIcon
                width: compact.ring ? parent.side * 0.58 : parent.side * 0.78
                height: width
                source: Qt.resolvedUrl("../icons/claude.svg")
                isMask: compact.cfg.monochromeIcon
                color: Kirigami.Theme.textColor
                opacity: root.hasData ? 1 : 0.5
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
            }

            ProgressRing {
                anchors.fill: parent
                anchors.margins: Math.round(parent.side * 0.06)
                visible: compact.ring
                value: Math.max(0, compact.util) / 100
                thickness: Math.max(2, Math.round(parent.side / 11))
                color: root.levelColor(compact.util, compact.cfg.monochromeIcon ? Kirigami.Theme.textColor : root.brand)
            }
        }

        PlasmaComponents.Label {
            id: label
            visible: compact.showText
            text: compact.valueText
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            font.features: { "tnum": 1 }   // tabular figures: no jitter as numbers change
            font.pixelSize: compact.vertical
                ? Math.max(Kirigami.Theme.smallFont.pixelSize * 0.9, Math.min(Kirigami.Theme.defaultFont.pixelSize, compact.width / 3.2))
                : Kirigami.Theme.defaultFont.pixelSize
            color: root.levelColor(compact.util, Kirigami.Theme.textColor)
            opacity: root.error && root.hasData ? 0.6 : 1
        }
    }
}
