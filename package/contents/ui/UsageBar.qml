import QtQuick
import org.kde.kirigami as Kirigami

// Slim rounded bar with a faint track. value: 0..100
Item {
    id: bar
    property real value: 0
    property color color: Kirigami.Theme.highlightColor
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.3)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Kirigami.Theme.textColor
        opacity: 0.1
    }
    Rectangle {
        height: parent.height
        radius: height / 2
        color: bar.color
        width: bar.value > 0 ? Math.max(height, parent.width * Math.min(100, bar.value) / 100) : 0
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
