import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    // Panel
    property string cfg_panelMetric
    property string cfg_panelStyle
    property alias cfg_panelShowIcon: panelShowIcon.checked
    property alias cfg_panelShowPercent: panelShowPercent.checked
    property alias cfg_panelShowReset: panelShowReset.checked
    property alias cfg_monochromeIcon: monochromeIcon.checked
    // Popup
    property alias cfg_showSession: showSession.checked
    property alias cfg_showWeekly: showWeekly.checked
    property alias cfg_showModels: showModels.checked
    property alias cfg_showOther: showOther.checked
    property alias cfg_showExtra: showExtra.checked
    property alias cfg_showAbsoluteTime: showAbsoluteTime.checked
    // Behaviour
    property alias cfg_refreshMinutes: refreshMinutes.value
    property alias cfg_warnThreshold: warnThreshold.value
    property alias cfg_criticalThreshold: criticalThreshold.value
    property alias cfg_credentialsPath: credentialsPath.text
    property alias cfg_mockData: mockData.checked

    readonly property var metricChoices: [
        { value: "session", text: i18n("Current session (5-hour)") },
        { value: "weekly",  text: i18n("Weekly · all models") },
        { value: "fable",   text: i18n("Weekly · Fable") },
        { value: "opus",    text: i18n("Weekly · Opus") },
        { value: "sonnet",  text: i18n("Weekly · Sonnet") },
        { value: "highest", text: i18n("Whichever is highest") }
    ]
    readonly property var styleChoices: [
        { value: "text", text: i18n("Icon and percentage") },
        { value: "ring", text: i18n("Progress ring around icon") }
    ]

    function indexOf(list, value) {
        for (var i = 0; i < list.length; i++)
            if (list[i].value === value)
                return i;
        return 0;
    }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("In the panel") }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Show:")
            model: metricChoices
            textRole: "text"
            valueRole: "value"
            currentIndex: indexOf(metricChoices, cfg_panelMetric)
            onActivated: cfg_panelMetric = currentValue
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Style:")
            model: styleChoices
            textRole: "text"
            valueRole: "value"
            currentIndex: indexOf(styleChoices, cfg_panelStyle)
            onActivated: cfg_panelStyle = currentValue
        }
        QQC2.CheckBox { id: panelShowIcon; Kirigami.FormData.label: i18n("Display:"); text: i18n("Icon") }
        QQC2.CheckBox { id: panelShowPercent; text: i18n("Percentage") }
        QQC2.CheckBox { id: panelShowReset; text: i18n("Time until reset (e.g. “42% · 2h”)") }
        QQC2.CheckBox { id: monochromeIcon; text: i18n("Monochrome icon (match panel text)") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("In the popup") }

        QQC2.CheckBox { id: showSession; Kirigami.FormData.label: i18n("Sections:"); text: i18n("Current session") }
        QQC2.CheckBox { id: showWeekly; text: i18n("Weekly · all models") }
        QQC2.CheckBox { id: showModels; text: i18n("Weekly · per model (Fable, Opus, Sonnet, …)") }
        QQC2.CheckBox { id: showOther; text: i18n("Other limits reported by the API") }
        QQC2.CheckBox { id: showExtra; text: i18n("Extra usage (when enabled)") }
        QQC2.CheckBox { id: showAbsoluteTime; Kirigami.FormData.label: i18n("Reset time:"); text: i18n("Also show clock time (e.g. “Tomorrow 09:00”)") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Behaviour") }

        QQC2.SpinBox {
            id: refreshMinutes
            Kirigami.FormData.label: i18n("Refresh every:")
            from: 1; to: 120
            textFromValue: (v) => i18np("%1 minute", "%1 minutes", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: warnThreshold
            Kirigami.FormData.label: i18n("Warn at:")
            from: 1; to: 100
            textFromValue: (v) => v + "%"
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: criticalThreshold
            Kirigami.FormData.label: i18n("Critical at:")
            from: 1; to: 100
            textFromValue: (v) => v + "%"
            valueFromText: (t) => parseInt(t)
        }
        QQC2.TextField {
            id: credentialsPath
            Kirigami.FormData.label: i18n("Credentials file:")
            placeholderText: "~/.claude/.credentials.json"
            Layout.fillWidth: true
        }
        QQC2.CheckBox { id: mockData; text: i18n("Use sample data (preview without signing in)") }
    }
}
