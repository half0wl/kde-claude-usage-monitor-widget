.pragma library

// Parsing for Claude's OAuth usage/profile endpoints. Pure functions, no I/O:
// main.qml does the reading (credentials via `cat`) and the HTTP requests.

var USAGE_URL = "https://api.anthropic.com/api/oauth/usage";
var PROFILE_URL = "https://api.anthropic.com/api/oauth/profile";
var BETA_HEADER = "oauth-2025-04-20";

// Fixed labels for windows whose names aren't simply a model name.
var LABELS = {
    five_hour: "Current session",
    seven_day: "All models",
    seven_day_oauth_apps: "Third-party apps"
};
// Preferred order of per-model rows; unknown models follow.
var MODEL_ORDER = ["fable", "opus", "sonnet", "haiku"];

// ---- credentials ---------------------------------------------------------

// Returns {token, expiresAt, subscriptionType, rateLimitTier} or throws.
function parseCredentials(text) {
    var data = JSON.parse(text);
    var o = (data && data.claudeAiOauth) || {};
    return {
        token: o.accessToken || "",
        expiresAt: typeof o.expiresAt === "number" ? o.expiresAt : 0,
        subscriptionType: o.subscriptionType || "",
        rateLimitTier: o.rateLimitTier || ""
    };
}

// ---- helpers -------------------------------------------------------------

function pretty(key) {
    var s = String(key).replace(/_/g, " ").trim();
    return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
}

function capitalize(s) {
    s = String(s);
    return s.charAt(0).toUpperCase() + s.slice(1);
}

// ISO-8601 -> epoch ms. V4's Date.parse rejects microseconds, so trim to millis.
function toMs(iso) {
    if (!iso)
        return null;
    var s = String(iso).replace(/(\.\d{3})\d+/, "$1").replace(/Z$/, "+00:00");
    var t = Date.parse(s);
    return isNaN(t) ? null : t;
}

function planName(sub, tier) {
    sub = String(sub || "").toLowerCase().replace("claude_", "");
    tier = String(tier || "").toLowerCase();
    if (!sub)
        return "";
    var names = { max: "Max", pro: "Pro", team: "Team", enterprise: "Enterprise", free: "Free" };
    var name = names[sub] || capitalize(sub);
    if (tier.indexOf("20x") !== -1)
        name += " 20×";
    else if (tier.indexOf("5x") !== -1)
        name += " 5×";
    return name;
}

function planFromProfile(profile) {
    var org = (profile && profile.organization) || {};
    var acct = (profile && profile.account) || {};
    var kind = org.organization_type || "";
    if (!kind)
        kind = acct.has_claude_max ? "max" : acct.has_claude_pro ? "pro" : "";
    return planName(kind, org.rate_limit_tier || "");
}

// ---- usage ---------------------------------------------------------------

function modelRank(slug) {
    var i = MODEL_ORDER.indexOf(slug);
    return i === -1 ? MODEL_ORDER.length : i;
}

// Legacy key -> {label, group, order}
//   five_hour -> session; seven_day -> weekly all; key containing a model name
//   or seven_day_<x> -> weekly per model; anything else -> other.
function classify(key) {
    if (key === "five_hour")
        return { label: LABELS.five_hour, group: "session", order: 0 };
    if (key.indexOf("five_hour_") === 0)
        return { label: pretty(key.slice(10)), group: "session", order: 1 };
    if (key === "seven_day")
        return { label: LABELS.seven_day, group: "weekly", order: 10 };
    var tokens = key.toLowerCase().split("_");
    for (var r = 0; r < MODEL_ORDER.length; r++)
        if (tokens.indexOf(MODEL_ORDER[r]) !== -1)
            return { label: capitalize(MODEL_ORDER[r]), group: "weekly", order: 20 + r };
    if (key.indexOf("seven_day_") === 0) {
        if (LABELS[key])
            return { label: LABELS[key], group: "weekly", order: 90 };
        var sub = key.slice(10);
        return { label: pretty(sub), group: "weekly", order: 20 + modelRank(sub) };
    }
    return { label: pretty(key), group: "other", order: 100 };
}

// Older response shape: every {"utilization": ...} object, also inside nested dicts/lists.
function legacyWindows(obj, prefix, out) {
    if (obj === null || typeof obj !== "object")
        return out;
    if (Array.isArray(obj)) {
        for (var i = 0; i < obj.length; i++) {
            var v = obj[i];
            var name = v && typeof v === "object" ? (v.model || v.name || v.key) : null;
            legacyWindows(v, prefix + "_" + (name || i), out);
        }
        return out;
    }
    if ("utilization" in obj && prefix && prefix.indexOf("extra_usage") !== 0) {
        out.push({ key: prefix, val: obj });
        return out;
    }
    for (var k in obj)
        legacyWindows(obj[k], prefix ? prefix + "_" + k : k, out);
    return out;
}

// Current response shape: the `limits` list.
//   {kind: "session"|"weekly_all"|"weekly_scoped"|…, group, percent, resets_at,
//    scope: {model: {display_name: "Fable"}, surface: …}}
function fromLimits(limits) {
    var out = [];
    for (var i = 0; i < limits.length; i++) {
        var item = limits[i];
        if (!item || typeof item !== "object")
            continue;
        var kind = String(item.kind || "");
        var scope = item.scope && typeof item.scope === "object" ? item.scope : {};
        var model = scope.model && typeof scope.model === "object" ? scope.model : {};
        var surface = scope.surface;
        var scoped = model.display_name || model.id || "";
        if (!scoped && surface)
            scoped = typeof surface === "object" ? (surface.display_name || surface.id || "") : String(surface);

        var m;
        if (kind === "session") {
            m = { key: "five_hour", label: LABELS.five_hour, group: "session", order: 0 };
        } else if (kind === "weekly_all") {
            m = { key: "seven_day", label: LABELS.seven_day, group: "weekly", order: 10 };
        } else if (scoped) {
            var slug = String(scoped).toLowerCase().replace(/ /g, "_");
            var group = item.group === "session" || item.group === "weekly" ? item.group : "other";
            m = {
                key: (group === "weekly" ? "seven_day_" : kind + "_") + slug,
                label: String(scoped),
                group: group,
                order: (group === "weekly" ? 20 : 100) + modelRank(slug)
            };
        } else {
            m = { key: kind || "limit", label: pretty(kind || "limit"), group: "other", order: 100 };
        }
        var pct = item.percent !== undefined ? item.percent : item.utilization;
        m.utilization = pct === null || pct === undefined ? null : Number(pct);
        m.resetsAt = toMs(item.resets_at);
        out.push(m);
    }
    return out;
}

function normalize(raw, plan) {
    var metrics = [];
    if (Array.isArray(raw.limits) && raw.limits.length > 0) {
        metrics = fromLimits(raw.limits);
    } else {
        var wins = legacyWindows(raw, "", []);
        for (var i = 0; i < wins.length; i++) {
            var c = classify(wins[i].key);
            var u = wins[i].val.utilization;
            metrics.push({
                key: wins[i].key,
                label: c.label,
                group: c.group,
                order: c.order,
                utilization: u === null || u === undefined ? null : Number(u),
                resetsAt: toMs(wins[i].val.resets_at)
            });
        }
    }
    metrics.sort(function (a, b) {
        return a.order - b.order || (a.label < b.label ? -1 : a.label > b.label ? 1 : 0);
    });

    var e = raw.extra_usage && typeof raw.extra_usage === "object" ? raw.extra_usage : null;
    var extra = e ? {
        enabled: !!e.is_enabled,
        monthlyLimit: e.monthly_limit === undefined ? null : e.monthly_limit,
        usedCredits: e.used_credits === undefined ? null : e.used_credits,
        utilization: e.utilization === undefined ? null : e.utilization
    } : null;

    return { metrics: metrics, extra: extra, plan: plan };
}

// ---- sample data -----------------------------------------------------------

function mock(nowMs) {
    function iso(dt) { return new Date(nowMs + dt * 1000).toISOString(); }
    var week = 3 * 86400 + 5 * 3600;
    return normalize({
        limits: [
            { kind: "session", group: "session", percent: 42, resets_at: iso(2 * 3600 + 14 * 60), scope: null },
            { kind: "weekly_all", group: "weekly", percent: 63, resets_at: iso(week), scope: null },
            { kind: "weekly_scoped", group: "weekly", percent: 37, resets_at: iso(week),
              scope: { model: { id: null, display_name: "Fable" }, surface: null } }
        ],
        extra_usage: { is_enabled: false }
    }, planName("max", "default_claude_max_20x"));
}
