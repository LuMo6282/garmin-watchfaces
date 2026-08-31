import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Both layouts implement this. FaceView owns the lifecycle and the
// data; a renderer only knows how to put pixels down.
class Renderer {

    protected var dark as Boolean = false;

    // Set from the metrics at the top of every draw. The palette is a
    // function of training status, so every colour has to be asked for
    // rather than read from a constant.
    protected var status as Number = Theme.STATUS_NONE;

    function initialize(isDark as Boolean) {
        dark = isDark;
    }

    protected function accent() as Number { return Theme.accent(dark, status); }
    protected function fg() as Number { return Theme.fgFor(dark, status); }
    protected function rule() as Number { return Theme.rule(dark); }
    protected function track() as Number { return Theme.track(dark); }
    protected function secondary() as Number { return Theme.secondary(dark); }
    protected function tertiary() as Number { return Theme.tertiary(dark); }

    // reveal runs 0.0 to 1.0 during the wrist-raise animation and
    // sits at 1.0 the rest of the time.
    function draw(dc as Dc, m as Metrics, reveal as Float) as Void {
    }

    // Redrawn once per second in low power on always-active MIP
    // devices. Never called on AMOLED, so nothing here is load-bearing.
    function drawPartial(dc as Dc, m as Metrics) as Void {
    }

    // Always-on state for burn-in-protected screens. Deliberately
    // shared by both layouts: at 1% brightness with a pixel budget,
    // there is no layout left to express, only the time.
    //
    // Lighting a cream background here would be the single fastest
    // way to get the face rejected in review and to burn the panel.
    function drawAmbient(dc as Dc, m as Metrics) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Theme.G_NONE);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        // Drift the whole thing on a slow cycle so no pixel holds the
        // same glyph for hours. Eight positions, one per minute mod 8.
        var phase = m.minute % 8;
        var dx = ((phase % 4) - 1.5) * 6;
        var dy = ((phase / 4) - 0.5) * 10;

        var font = FaceFonts.time();
        var x = (w / 2) + dx.toNumber();
        var y = (h / 2) - (dc.getFontHeight(font) / 2) + dy.toNumber();

        // Dimmed, not full cream. Fewer lit subpixels, less burn.
        text(dc, x, y, font, m.timeString(), 0x9A968C, Graphics.TEXT_JUSTIFY_CENTER);
    }

    protected function clear(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Theme.bg(dark, status));
        dc.clear();
    }

    // Sweeps CLOCKWISE from fromDeg. Garmin measures degrees
    // counter-clockwise from 3 o'clock, so clockwise means decreasing.
    // Both progress arcs are anchored at the end a full reading would
    // start from and grow away from it — steps climb the left edge,
    // body battery falls down the right — which is why this takes a
    // direction at all rather than the raw start/end pair.
    protected function arc(
        dc as Dc,
        cx as Number, cy as Number, radius as Number,
        fromDeg as Float, sweepDeg as Float,
        color as Number, width as Number
    ) as Void {
        if (sweepDeg <= 0.5) { return; }
        if (sweepDeg > 359.0) { sweepDeg = 359.0; }

        var to = fromDeg - sweepDeg;
        while (to < 0.0) { to += 360.0; }
        while (to >= 360.0) { to -= 360.0; }

        // drawArc lays down butt ends. Every arc on this face wants a
        // rounded one: the sun dial is stamped from discs and so ends
        // round, and a square end and a round end sitting on the same
        // circle stop reading as the same stroke.
        //
        // The caps go at the INTEGER angles drawArc is actually handed,
        // not the float ones they came from. drawArc takes whole degrees
        // and at this radius one degree is over 3px, so a cap placed at
        // the true angle can sit clear of the end that got painted.
        var a = fromDeg.toNumber();
        var b = to.toNumber();

        // drawArc paints a COMPLETE circle when start and end land on the
        // same degree, so a sweep too small to survive truncation would
        // throw a ring right across the face. The sweepDeg guard above
        // does not cover this: a 0.6 degree sweep from 213.8 truncates to
        // drawArc(213, 213).
        if (a == b) { return; }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(width);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, a, b);
        dc.setPenWidth(1);

        var capR = width / 2;
        if (capR > 0) {
            cap(dc, cx, cy, radius, a, capR);
            cap(dc, cx, cy, radius, b, capR);
        }
    }

    // A disc the width of the pen, centred on the arc's end. Radius is
    // width/2, which is the same disc the sun dial's ramp is built from,
    // so the two strokes end identically.
    hidden function cap(
        dc as Dc,
        cx as Number, cy as Number, radius as Number,
        deg as Number, capR as Number
    ) as Void {
        var rad = deg * Math.PI / 180.0;
        dc.fillCircle(
            cx + (radius * Math.cos(rad)).toNumber(),
            cy - (radius * Math.sin(rad)).toNumber(),
            capR
        );
    }

    // Linear RGB mix. Needed because Garmin draws arcs in one flat
    // colour: a gradient has to be built out of adjacent segments, each
    // asking for its own step along the ramp.
    protected function blend(a as Number, b as Number, t as Float) as Number {
        var u = t;
        if (u < 0.0) { u = 0.0; }
        if (u > 1.0) { u = 1.0; }

        var ar = (a >> 16) & 0xFF;
        var ag = (a >> 8) & 0xFF;
        var ab = a & 0xFF;

        var r = (ar + (((b >> 16) & 0xFF) - ar) * u).toNumber();
        var g = (ag + (((b >> 8) & 0xFF) - ag) * u).toNumber();
        var bl = (ab + ((b & 0xFF) - ab) * u).toNumber();

        return (r << 16) | (g << 8) | bl;
    }

    protected function text(
        dc as Dc,
        x as Number, y as Number,
        font as FontType,
        value as String,
        color as Number,
        justify as TextJustification
    ) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, value, justify);
    }

    // Draws with the baseline at baseY rather than the top of the line
    // box, so runs set in different sizes can share a baseline.
    protected function baseline(
        dc as Dc,
        x as Number, baseY as Number,
        font as FontType,
        value as String,
        color as Number,
        justify as TextJustification
    ) as Void {
        text(dc, x, baseY - Graphics.getFontAscent(font), font, value, color, justify);
    }

    // Letterspaced text, drawn a character at a time. Reserved for the
    // small lowercase labels, where opening the tracking is what stops
    // them reading as a cramped afterthought under the time.
    protected function tracked(
        dc as Dc,
        x as Number, baseY as Number,
        font as FontType,
        value as String,
        color as Number,
        extra as Number,
        justify as TextJustification
    ) as Void {
        var width = trackedWidth(dc, font, value, extra);
        var left = x;
        if (justify == Graphics.TEXT_JUSTIFY_CENTER) {
            left = x - (width / 2);
        }

        var y = baseY - Graphics.getFontAscent(font);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < value.length(); i += 1) {
            var ch = value.substring(i, i + 1) as String;
            dc.drawText(left, y, font, ch, Graphics.TEXT_JUSTIFY_LEFT);
            left += dc.getTextWidthInPixels(ch, font) + extra;
        }
    }

    protected function trackedWidth(
        dc as Dc, font as FontType, value as String, extra as Number
    ) as Number {
        if (value.length() == 0) { return 0; }
        return dc.getTextWidthInPixels(value, font) + (extra * (value.length() - 1));
    }

    // Joins as many parts as will fit, in the order given, and drops the
    // rest. Both layouts have a hard width budget — the ring on one, the
    // bezel curve on the other — so a line shortens rather than clipping
    // or colliding.
    protected function fitJoin(
        dc as Dc, font as FontType, parts as Array<String>,
        room as Number, extra as Number
    ) as String {
        var line = "";
        for (var i = 0; i < parts.size(); i += 1) {
            var candidate = line.equals("") ? parts[i] : line + "  ·  " + parts[i];
            if (trackedWidth(dc, font, candidate, extra) > room) { break; }
            line = candidate;
        }
        return line;
    }

    // Sun marker: a small solid triangle, up for the next sunrise and
    // down for the next sunset. Drawn rather than set, because the
    // subset serif carries no arrow glyphs and adding two for this
    // would cost more than the shape does.
    protected function sunMark(
        dc as Dc, cx as Number, baseY as Number, up as Boolean, color as Number
    ) as Void {
        var w = 5;
        var h = 6;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (up) {
            dc.fillPolygon([[cx, baseY - h], [cx - w, baseY], [cx + w, baseY]]);
        } else {
            dc.fillPolygon([[cx, baseY], [cx - w, baseY - h], [cx + w, baseY - h]]);
        }
    }

    // Cheap linear fade toward the background. Real alpha blending is
    // not available on MIP, so the wake animation eases position and
    // arc length instead of opacity wherever it can.
    protected function eased(reveal as Float) as Float {
        var t = reveal;
        if (t < 0.0) { t = 0.0; }
        if (t > 1.0) { t = 1.0; }
        return 1.0 - ((1.0 - t) * (1.0 - t));
    }
}
