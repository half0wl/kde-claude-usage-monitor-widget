.pragma library

// "in 2h 14m", "in 3d 5h", "in 12m", "in <1m"
// All timestamps are epoch milliseconds.
function relative(t, nowMs) {
    if (!t)
        return "";
    var s = Math.round((t - nowMs) / 1000);
    if (s <= 0)
        return "now";
    var d = Math.floor(s / 86400);
    var h = Math.floor((s % 86400) / 3600);
    var m = Math.floor((s % 3600) / 60);
    if (d > 0)
        return "in " + d + "d" + (h > 0 ? " " + h + "h" : "");
    if (h > 0)
        return "in " + h + "h" + (m > 0 ? " " + m + "m" : "");
    if (m > 0)
        return "in " + m + "m";
    return "in <1m";
}

// Compact form without "in": "2h", "3d", "14m"
function short(t, nowMs) {
    if (!t)
        return "";
    var s = Math.round((t - nowMs) / 1000);
    if (s <= 0)
        return "";
    if (s >= 86400)
        return Math.floor(s / 86400) + "d";
    if (s >= 3600)
        return Math.floor(s / 3600) + "h";
    return Math.max(1, Math.floor(s / 60)) + "m";
}

// "15:30", "Tomorrow 15:30", "Fri 15:30", "Nov 28"
function absolute(ms, nowMs, locale, timeFmt) {
    if (!ms)
        return "";
    var t = new Date(ms);
    var now = new Date(nowMs);
    var dayMs = 86400000;
    var startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    var diffDays = Math.floor((t.getTime() - startToday) / dayMs);
    var time = t.toLocaleTimeString(locale, timeFmt);
    if (diffDays === 0)
        return time;
    if (diffDays === 1)
        return "Tomorrow " + time;
    if (diffDays < 7)
        return t.toLocaleDateString(locale, "ddd") + " " + time;
    return t.toLocaleDateString(locale, "MMM d");
}

function ago(ms, nowMs) {
    if (!ms)
        return "";
    var s = Math.round((nowMs - ms) / 1000);
    if (s < 45)
        return "just now";
    if (s < 3600)
        return Math.round(s / 60) + " min ago";
    if (s < 86400)
        return Math.round(s / 3600) + " h ago";
    return Math.round(s / 86400) + " d ago";
}

function pct(v) {
    if (v === null || v === undefined || isNaN(v))
        return "–";
    return Math.round(v) + "%";
}
