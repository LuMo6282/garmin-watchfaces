import Toybox.Graphics;
import Toybox.Lang;

// Layout A. The time is the page; everything else is a caption.
//
// The arcs carry steps and body battery, so neither is repeated as a
// number — the old stat row said the same thing twice, which is what
// made the face read as data scattered on a background rather than a
// composition. What is left below the time is the step count, which is
// the one figure worth reading exactly, and a quiet line of the things
// no arc shows.
class ArcsRenderer extends Renderer {

    // Vertical rhythm, as fractions of screen height. The gaps tighten
    // going down the face; that is what makes the stack read as
    // deliberate rather than as four bands floating apart.
    hidden const DOT_Y      = 0.120;
    hidden const DATE_BASE  = 0.238;
    hidden const TIME_RISE  = 10;
    hidden const STEPS_GAP  = 34;
    hidden const STATUS_GAP = 26;
    hidden const FOOTER_GAP = 24;
    hidden const SUN_Y      = 0.885;
    hidden const FOOTER_ROOM = 0.60;

    hidden const ARC_INSET  = 15;
    hidden const ARC_WIDTH  = 7;

    // One ring split into two sectors rather than a pair of short
    // brackets: a hairline gap at 12 and another at 6, and each metric
    // owns a full side. Twice the arc per percent, so a day's progress
    // is legible as a shape instead of a stub.
    hidden const RING_GAP   = 13.0;
    hidden const ARC_SPAN   = 180.0 - RING_GAP;

    // Anchors are unchanged in spirit: steps climb the left edge from
    // the bottom, body battery falls down the right edge from the top.
    hidden const STEPS_FROM = 270.0 - (RING_GAP / 2);
    hidden const BODY_FROM  = 90.0 - (RING_GAP / 2);

    function initialize(isDark as Boolean) {
        Renderer.initialize(isDark);
    }

    function draw(dc as Dc, m as Metrics, reveal as Float) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        // The palette follows training status, so it has to be settled
        // before anything is painted — including the background.
        status = m.trainingStatus;

        clear(dc);
        drawArcs(dc, m, cx, cy, w, eased(reveal));
        drawDate(dc, m, cx, h);

        var base = drawTime(dc, m, cx, cy);
        base = drawStatus(dc, m, cx, base);
        drawFooter(dc, m, cx, base);
        drawSun(dc, m, cx, h);
    }

    // Only an arc with something to say gets drawn — track included.
    // A lone empty track on a device without body battery is exactly
    // the placeholder gap the face is supposed to never show.
    hidden function drawArcs(
        dc as Dc, m as Metrics,
        cx as Number, cy as Number, w as Number, t as Float
    ) as Void {
        var radius = (w / 2) - ARC_INSET;

        var stepPct = m.stepProgress();
        if (stepPct != null) {
            arc(dc, cx, cy, radius, STEPS_FROM, ARC_SPAN, track(), ARC_WIDTH);
            arc(dc, cx, cy, radius, STEPS_FROM, ARC_SPAN * stepPct * t, accent(), ARC_WIDTH);
        }

        var bodyPct = m.bodyProgress();
        if (bodyPct != null) {
            arc(dc, cx, cy, radius, BODY_FROM, ARC_SPAN, track(), ARC_WIDTH);
            arc(dc, cx, cy, radius, BODY_FROM, ARC_SPAN * bodyPct * t, accent(), ARC_WIDTH);
        }
    }

    hidden function drawDate(dc as Dc, m as Metrics, cx as Number, h as Number) as Void {
        // Unread notifications get the accent, but only as a dot.
        if (m.notifications > 0) {
            dc.setColor(accent(), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, (h * DOT_Y).toNumber(), 4);
        }

        tracked(
            dc, cx, (h * DATE_BASE).toNumber(), FaceFonts.label(),
            m.dateLine, secondary(), 3, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // Deliberately not animated. The time is the reason the screen is
    // on; making it arrive late is a tax on every wrist raise.
    // Returns its baseline so what follows can hang off the type rather
    // than off another guessed fraction of the screen.
    hidden function drawTime(
        dc as Dc, m as Metrics, cx as Number, cy as Number
    ) as Number {
        var font = FaceFonts.time();
        var top = cy - TIME_RISE - (Graphics.getFontAscent(font) / 2);

        text(
            dc, cx, top, font, m.timeString(),
            fg(), Graphics.TEXT_JUSTIFY_CENTER
        );
        return top + Graphics.getFontAscent(font);
    }

    // The word that explains the colour. Everything else on the face is
    // neutral, so this line and the rings are the only places the accent
    // appears — which makes the accent legible as information rather
    // than styling. Steps stay on the ring; the exact count was saying
    // the same thing twice.
    hidden function drawStatus(
        dc as Dc, m as Metrics, cx as Number, timeBase as Number
    ) as Number {
        var font = FaceFonts.label();
        var base = timeBase + STATUS_GAP + Graphics.getFontAscent(font);
        if (m.trainingLabel == null) { return timeBase; }

        tracked(
            dc, cx, base, font, m.trainingLabel as String,
            accent(), 3, Graphics.TEXT_JUSTIFY_CENTER
        );
        return base;
    }

    // What your body is doing: recovery and heart rate. Temperature
    // belongs with the sun on the line below — that one is the world
    // outside, this one is you.
    // takes only what the rim leaves room for and drops the rest, so it
    // can neither clip nor collide with the ring.
    hidden function drawFooter(
        dc as Dc, m as Metrics, cx as Number, statusBase as Number
    ) as Void {
        var parts = [] as Array<String>;
        if (m.recoveryHours != null) { parts.add(m.recoveryHours.format("%d") + "h recovery"); }
        if (m.heartRate != null) { parts.add(m.heartRate.format("%d") + " bpm"); }
        if (parts.size() == 0) { return; }

        var font = FaceFonts.micro();
        var line = fitJoin(dc, font, parts, (cx * 2 * FOOTER_ROOM).toNumber(), 1);
        if (line.equals("")) { return; }

        tracked(
            dc, cx, statusBase + FOOTER_GAP + Graphics.getFontAscent(font),
            font, line, tertiary(), 1, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // The world outside: whichever of sunrise or sunset comes next, and
    // the temperature. A triangle points up for a sunrise still to come
    // and down for a sunset, so the mark reads before the number does.
    hidden function drawSun(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        var time = m.sunString();
        var line = time;
        if (m.temperature != null) {
            var temp = m.temperature.format("%d") + "°F";
            line = time == null ? temp : time + "  ·  " + temp;
        }
        if (line == null) { return; }

        var font = FaceFonts.micro();
        var base = (h * SUN_Y).toNumber();
        var mark = time == null ? 0 : 17;
        var width = mark + trackedWidth(dc, font, line as String, 1);
        var left = cx - (width / 2);

        if (time != null) {
            sunMark(dc, left + 5, base, m.sunIsRise, secondary());
        }
        tracked(
            dc, left + mark, base, font, line as String,
            secondary(), 1, Graphics.TEXT_JUSTIFY_LEFT
        );
    }

}
