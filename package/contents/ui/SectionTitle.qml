import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Quiet, small-caps style group label.
PlasmaComponents.Label {
    Layout.fillWidth: true
    Layout.leftMargin: Kirigami.Units.largeSpacing
    Layout.rightMargin: Kirigami.Units.largeSpacing
    Layout.bottomMargin: -Kirigami.Units.smallSpacing
    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
    font.weight: Font.DemiBold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.6
    opacity: 0.5
}
