import QtQuick
import QtQuick.Shapes

// Thin circular progress ring with a faint track. value: 0..1
Item {
    id: ring
    property real value: 0
    property real thickness: 3
    property color color: "#D97757"
    property color trackColor: Qt.rgba(color.r, color.g, color.b, 0.18)

    readonly property real r: Math.min(width, height) / 2 - thickness / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeColor: ring.trackColor
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.r; radiusY: ring.r
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.value > 0 ? ring.color : "transparent"
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.r; radiusY: ring.r
                startAngle: -90
                sweepAngle: 360 * Math.min(1, Math.max(0, ring.value))
                Behavior on sweepAngle { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }
}
