import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import "Format.js" as Fmt
import "Api.js" as Api

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    // ---- state -------------------------------------------------------------
    property var metrics: []          // [{key,label,group,utilization,resetsAt}]
    property var extra: null
    property string plan: ""
    property string error: ""         // last error (data may still be shown, stale)
    property string errorHint: ""
    property real lastSuccess: 0
    property bool loading: false
    property real now: Date.now()

    readonly property bool hasData: metrics.length > 0
    readonly property color brand: "#D97757"

    // The metric shown in the panel.
    readonly property var panelMetric: {
        if (!hasData)
            return null;
        if (cfg.panelMetric === "highest") {
            var best = null;
            for (var i = 0; i < metrics.length; i++) {
                var m = metrics[i];
                if (m.utilization !== null && (best === null || m.utilization > best.utilization))
                    best = m;
            }
            return best;
        }
        return findMetric(cfg.panelMetric) || metrics[0];
    }

    // "session" | "weekly" | a model name ("fable", "opus", …) | a raw API key
    function findMetric(choice) {
        if (choice === "session")
            return metricByKey("five_hour");
        if (choice === "weekly")
            return metricByKey("seven_day");
        // Match the model name as a word, so "Opus" also finds "Claude Opus 5".
        for (var i = 0; i < metrics.length; i++)
            if (metrics[i].group === "weekly"
                    && metrics[i].label.toLowerCase().split(/\s+/).indexOf(choice) !== -1)
                return metrics[i];
        return metricByKey(choice);
    }

    function metricByKey(key) {
        for (var i = 0; i < metrics.length; i++)
            if (metrics[i].key === key)
                return metrics[i];
        return null;
    }

    function levelColor(util, fallback) {
        if (util === null || util === undefined)
            return fallback;
        if (util >= cfg.criticalThreshold)
            return Kirigami.Theme.negativeTextColor;
        if (util >= cfg.warnThreshold)
            return Kirigami.Theme.neutralTextColor;
        return fallback;
    }

    // ---- fetching ----------------------------------------------------------
    // 1. `cat` the Claude Code credentials file (the only thing QML can't read itself)
    // 2. GET the usage endpoint with the OAuth token (XMLHttpRequest)
    // 3. GET the profile at most hourly for the plan name; .credentials.json records
    //    the plan at sign-in and goes stale after an upgrade.
    // The token only lives in memory for the duration of a refresh; it is never logged.
    readonly property int requestTimeoutMs: 15000
    readonly property int planTtlMs: 3600000
    property real planFetchedAt: 0
    property var pendingXhr: null

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function credentialsCommand() {
        var p = String(cfg.credentialsPath || "").trim();
        if (!p)
            return 'cat -- "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"';
        if (p === "~")
            return 'cat -- "$HOME"';
        if (p.indexOf("~/") === 0)
            return 'cat -- "$HOME"/' + shellQuote(p.slice(2));
        return "cat -- " + shellQuote(p);
    }

    function refresh() {
        if (loading)
            return;
        if (cfg.mockData) {
            apply(Api.mock(Date.now()));
            return;
        }
        loading = true;
        // Unique suffix (a shell comment) so identical commands always re-run.
        executable.connectSource(credentialsCommand() + " #" + Date.now());
    }

    function fail(message, hint) {
        loading = false;
        now = Date.now();
        error = message;
        errorHint = hint || "";
    }

    function apply(res) {
        loading = false;
        now = Date.now();
        error = "";
        errorHint = "";
        metrics = res.metrics;
        extra = res.extra;
        if (res.plan)
            plan = res.plan;
        lastSuccess = now;
    }

    function getJson(url, token, onDone) {
        var xhr = new XMLHttpRequest();
        pendingXhr = xhr;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (pendingXhr === xhr) {
                pendingXhr = null;
                xhrTimeout.stop();
            }
            var body = null;
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    body = JSON.parse(xhr.responseText);
                } catch (e) {
                    onDone(-1, null);
                    return;
                }
            }
            onDone(xhr.status, body);
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("Authorization", "Bearer " + token);
        xhr.setRequestHeader("anthropic-beta", Api.BETA_HEADER);
        xhr.setRequestHeader("Accept", "application/json");
        xhr.send();
        xhrTimeout.restart();
    }

    function handleCredentials(exitCode, stdout) {
        if (exitCode !== 0 || !stdout) {
            fail(i18n("Not signed in"), i18n("Run `claude` and log in with your Claude subscription."));
            return;
        }
        var creds;
        try {
            creds = Api.parseCredentials(stdout);
        } catch (e) {
            fail(i18n("Can't read credentials"), i18n("The credentials file isn't valid JSON."));
            return;
        }
        if (!creds.token) {
            fail(i18n("No OAuth token found"), i18n("Log in to Claude Code with a Claude.ai subscription (not an API key)."));
            return;
        }
        var fallbackPlan = Api.planName(creds.subscriptionType, creds.rateLimitTier);

        getJson(Api.USAGE_URL, creds.token, function (status, raw) {
            if (status === 401 || status === 403) {
                if (creds.expiresAt && creds.expiresAt < Date.now())
                    fail(i18n("Login expired"), i18n("Open Claude Code once to refresh your session."));
                else
                    fail(i18n("Not authorized"), i18n("Log in to Claude Code again (`claude` → /login)."));
                return;
            }
            if (status === 429) {
                fail(i18n("Rate limited"), i18n("Try a longer refresh interval."));
                return;
            }
            if (status === 0) {
                fail(i18n("Offline"), i18n("Can't reach api.anthropic.com. Will retry automatically."));
                return;
            }
            if (status === -1 || (status >= 200 && status < 300 && (!raw || typeof raw !== "object"))) {
                fail(i18n("Unexpected response"), i18n("The usage API returned something unreadable."));
                return;
            }
            if (status < 200 || status >= 300) {
                fail(i18n("Server error (HTTP %1)", status), i18n("Will retry automatically."));
                return;
            }

            if (Date.now() - planFetchedAt < planTtlMs && plan) {
                apply(Api.normalize(raw, plan));
                return;
            }
            getJson(Api.PROFILE_URL, creds.token, function (pStatus, profile) {
                var p = pStatus >= 200 && pStatus < 300 ? Api.planFromProfile(profile) : "";
                if (p)
                    planFetchedAt = Date.now();
                apply(Api.normalize(raw, p || plan || fallbackPlan));
            });
        });
    }

    Timer {
        id: xhrTimeout
        interval: root.requestTimeoutMs
        onTriggered: {
            if (root.pendingXhr) {
                var x = root.pendingXhr;
                root.pendingXhr = null;
                x.abort();  // fires onreadystatechange with status 0 -> "Offline"
            }
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            root.handleCredentials(data["exit code"], data["stdout"] || "");
        }
    }

    Timer {
        interval: Math.max(1, root.cfg.refreshMinutes) * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Keeps relative times ("in 2h 14m") ticking without re-fetching.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Connections {
        target: root.cfg
        function onMockDataChanged() { root.refresh(); }
        function onCredentialsPathChanged() { root.planFetchedAt = 0; root.refresh(); }
    }

    // Re-fetch when the popup opens if the data is older than a minute.
    onExpandedChanged: () => {
        now = Date.now();
        if (root.expanded && now - lastSuccess > 60000)
            refresh();
    }

    // ---- presentation ------------------------------------------------------
    Plasmoid.icon: Qt.resolvedUrl("../icons/claude.svg")
    Plasmoid.status: hasData && panelMetric && panelMetric.utilization >= cfg.criticalThreshold
                     ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus

    toolTipMainText: panelMetric
                     ? i18n("Claude · %1 %2", panelMetric.label.toLowerCase(), Fmt.pct(panelMetric.utilization))
                     : i18n("Claude Usage Monitor")
    toolTipSubText: {
        if (!hasData)
            return error ? error : i18n("Loading…");
        var r = Fmt.relative(panelMetric.resetsAt, now);
        var s = r ? i18n("Resets %1", r) : "";
        if (error)
            s += (s ? "\n" : "") + error;
        return s;
    }

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 10

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh now")
            icon.name: "view-refresh"
            onTriggered: root.refresh()
        },
        PlasmaCore.Action {
            text: i18n("Open usage page")
            icon.name: "internet-web-browser"
            onTriggered: Qt.openUrlExternally("https://claude.ai/settings/usage")
        }
    ]
}
