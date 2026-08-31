import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Layout A — Meridian. Two mirrored arcs and a page of type between them.
//
// The top arc is the day: it runs from sunrise on the left to sunset on
// the right, and a cream disc rides it at the current hour. The part the
// sun has already crossed is lit; the rest is an empty track. After
// sunset the disc is simply gone — the sun is below the horizon, so it
// is not on the arc — and the label switches to tomorrow's sunrise.
//
// The bottom arc is the body: readiness, filling as the recovery clock
// runs down. Both arcs grow left to right, so the pair reads as one
// movement rather than as two gauges that happen to face each other.
//
// Everything coloured — both arcs and the status word — is the training
// status colour, so the whole face changes character with the training,
// and the numerals stay neutral cream on top of it.
class MeridianRenderer extends Renderer {

    hidden const ARC_INSET  = 14;
    hidden const ARC_WIDTH  = 6;
    hidden const TRACK_WIDTH = 4;

    // The day arc: 160° down to 20°, so it spans the top with the ends
    // left low and level. The body arc mirrors it across the horizon.
    hidden const DAY_FROM   = 160.0;
    hidden const DAY_SPAN   = 140.0;
    hidden const BODY_FROM  = 200.0;
    hidden const BODY_SPAN  = 140.0;

    hidden const SUN_R      = 7;
    hidden const END_INSET  = 30;   // how far inside an arc end its label sits

    // Vertical rhythm as fractions of height, and fixed gaps below the
    // time so the lower stack hangs off the type rather than off another
    // guessed fraction.
    hidden const TEMP_Y     = 0.170;
    hidden const DATE_Y     = 0.300;
    hidden const TIME_RISE  = 6;
    hidden const STATUS_GAP = 24;
    hidden const PULSE_GAP  = 20;
    hidden const READY_Y    = 0.855;

    function initialize(isDark as Boolean) {
        Renderer.initialize(isDark);
    }

    function draw(dc as Dc, m as Metrics, reveal as Float) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w / 2) - ARC_INSET;
        var t = eased(reveal);

        // The palette is a function of training status, so it has to be
        // settled before anything is painted — the ground included.
        status = m.trainingStatus;
        clear(dc);

        drawDay(dc, m, cx, cy, r, t);
        drawBody(dc, m, cx, cy, r, t);

        drawSunLabel(dc, m, cx, cy, r);
        drawTemp(dc, m, cx, h);
        drawDate(dc, m, cx, h);

        var base = drawTime(dc, m, cx, cy);
        base = drawStatus(dc, m, cx, base);
        drawPulse(dc, m, cx, base);
        drawReadyLabel(dc, m, cx, h);
    }

    // The day. Track first, then however much of it the sun has crossed,
    // then the sun itself. Nothing is drawn at all on a device that
    // cannot say when the sun rises — an empty track with no disc on it
    // would be a gauge reading zero, which is not the same as silence.
    hidden function drawDay(
        dc as Dc, m as Metrics,
        cx as Number, cy as Number, r as Number, t as Float
    ) as Void {
        if (!m.hasDaylight()) { return; }

        arc(dc, cx, cy, r, DAY_FROM, DAY_SPAN, track(), TRACK_WIDTH);

        var f = m.dayProgress();
        if (f == null) { return; }   // night: the track stands empty

        var travelled = DAY_SPAN * f * t;
        arc(dc, cx, cy, r, DAY_FROM, travelled, accent(), ARC_WIDTH);

        // The disc sits on the arc, not beside it, so it has to be
        // punched out of the track it covers before it is drawn.
        var deg = DAY_FROM - travelled;
        var sx = cx + polarX(r, deg);
        var sy = cy + polarY(r, deg);

        dc.setColor(Theme.bg(dark, status), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy, SUN_R + 3);
        dc.setColor(fg(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy, SUN_R);
    }

    // The body. Readiness fills from the same side the day starts on, so
    // both arcs sweep the same way and the face reads as one clock rather
    // than two. Drawn from the far end backwards because the arc helper
    // sweeps clockwise and this one grows the other way.
    hidden function drawBody(
        dc as Dc, m as Metrics,
        cx as Number, cy as Number, r as Number, t as Float
    ) as Void {
        var ready = m.readiness();
        if (ready == null) { return; }

        arc(dc, cx, cy, r, BODY_FROM + BODY_SPAN, BODY_SPAN, track(), TRACK_WIDTH);

        var len = BODY_SPAN * ready * t;
        arc(dc, cx, cy, r, BODY_FROM + len, len, accent(), ARC_WIDTH);
    }

    // Whichever sun event is next, set at the end of the arc it belongs
    // to: a rise at the left end, a set at the right. The triangle says
    // which without spending a word on it.
    hidden function drawSunLabel(
        dc as Dc, m as Metrics,
        cx as Number, cy as Number, r as Number
    ) as Void {
        var value = m.sunString();
        if (value == null) { return; }

        var deg = m.sunIsRise ? DAY_FROM : (DAY_FROM - DAY_SPAN);
        var rr = r - END_INSET;
        var px = cx + polarX(rr, deg);
        var py = cy + polarY(rr, deg);

        var font = FaceFonts.micro();
        var width = 15 + trackedWidth(dc, font, value, 1);
        var left = px - (width / 2);
        var base = py + (Graphics.getFontAscent(font) / 2);

        sunMark(dc, left + 5, base, m.sunIsRise, secondary());
        tracked(dc, left + 15, base, font, value,
            secondary(), 1, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Temperature belongs to the sky, so it sits under the apex of the
    // sky's arc rather than down in the body's half of the face.
    hidden function drawTemp(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        if (m.temperature == null) { return; }

        var font = FaceFonts.micro();
        tracked(
            dc, cx, (h * TEMP_Y).toNumber(), font,
            m.temperature.format("%d") + "°F",
            secondary(), 2, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    hidden function drawDate(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        tracked(
            dc, cx, (h * DATE_Y).toNumber(), FaceFonts.label(),
            m.dateLine, tertiary(), 3, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // Never animated. The time is the reason the screen came on; making
    // it arrive late is a tax on every wrist raise. Returns its baseline
    // so the rest of the stack hangs off the type.
    hidden function drawTime(
        dc as Dc, m as Metrics, cx as Number, cy as Number
    ) as Number {
        var font = FaceFonts.time();
        var top = cy - TIME_RISE - (Graphics.getFontAscent(font) / 2);
        text(dc, cx, top, font, m.timeString(), fg(), Graphics.TEXT_JUSTIFY_CENTER);
        return top + Graphics.getFontAscent(font);
    }

    // The word that explains the colour. Without it the palette is just
    // a mood; with it, the colour is a reading.
    hidden function drawStatus(
        dc as Dc, m as Metrics, cx as Number, timeBase as Number
    ) as Number {
        if (m.trainingLabel == null) { return timeBase; }

        var font = FaceFonts.label();
        var base = timeBase + STATUS_GAP + Graphics.getFontAscent(font);
        tracked(dc, cx, base, font, m.trainingLabel as String,
            accent(), 3, Graphics.TEXT_JUSTIFY_CENTER);
        return base;
    }

    hidden function drawPulse(
        dc as Dc, m as Metrics, cx as Number, statusBase as Number
    ) as Void {
        if (m.heartRate == null) { return; }

        var font = FaceFonts.micro();
        tracked(
            dc, cx, statusBase + PULSE_GAP + Graphics.getFontAscent(font),
            font, m.heartRate.format("%d") + " bpm",
            tertiary(), 1, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // What the bottom arc means, in one word or one number. Suppressed
    // entirely when there is no arc to explain.
    hidden function drawReadyLabel(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        if (m.readiness() == null) { return; }

        var font = FaceFonts.micro();
        tracked(
            dc, cx, (h * READY_Y).toNumber(), font, m.recoveryLabel(),
            secondary(), 2, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // Screen offsets for a point on the rim. Garmin measures degrees
    // counter-clockwise from 3 o'clock while y grows downward, so the
    // vertical term is negated.
    hidden function polarX(r as Number, deg as Float) as Number {
        return (r * Math.cos(deg * Math.PI / 180.0)).toNumber();
    }

    hidden function polarY(r as Number, deg as Float) as Number {
        return -(r * Math.sin(deg * Math.PI / 180.0)).toNumber();
    }
}
