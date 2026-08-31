import Toybox.Graphics;
import Toybox.Lang;

// Layout B. The same material set as a page rather than a dial:
// everything hangs off one left margin, and the eye reads down a
// column instead of around a centre.
class ColumnRenderer extends Renderer {

    // Left margin has to clear the bezel curve, so it is a fraction of
    // width rather than a fixed pixel count. Slightly tighter than the
    // optical centre would want — the asymmetry is what makes it read
    // as set type instead of a centred stack that missed.
    hidden const MARGIN     = 0.165;
    hidden const DATE_BASE  = 0.225;
    hidden const TIME_GAP   = 22;
    hidden const LINE_GAP   = 9;
    hidden const RULE_GAP   = 18;
    // How much of the width a stacked line may occupy before the
    // bezel curve starts eating it at this height.
    hidden const LINE_ROOM  = 0.62;

    function initialize(isDark as Boolean) {
        Renderer.initialize(isDark);
    }

    function draw(dc as Dc, m as Metrics, reveal as Float) as Void {
        status = m.trainingStatus;
        clear(dc);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var x = (w * MARGIN).toNumber();

        var labelFont = FaceFonts.label();

        // Date
        var base = (h * DATE_BASE).toNumber();
        tracked(dc, x, base, labelFont, m.dateLine,
            secondary(), 3, Graphics.TEXT_JUSTIFY_LEFT);

        // Time — the one large thing on the face, and never animated.
        var timeFont = FaceFonts.time();
        base += TIME_GAP + Graphics.getFontAscent(timeFont);
        baseline(dc, x, base, timeFont, m.timeString(),
            fg(), Graphics.TEXT_JUSTIFY_LEFT);

        // A rule the width of the time, which is what ties the small
        // lines below to the block above instead of leaving them adrift.
        var ruleY = base + RULE_GAP;
        var ruleW = dc.getTextWidthInPixels(m.timeString(), timeFont);
        dc.setColor(rule(), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, ruleY, x + ruleW, ruleY);

        base = ruleY + RULE_GAP + Graphics.getFontAscent(labelFont);
        base = drawLine(dc, x, base, m.trainingLabel, accent());
        base = drawLine(dc, x, base, vitals(m), secondary());
        base = drawLine(dc, x, base, ambient(dc, m, (w * LINE_ROOM).toNumber()),
            tertiary());
    }

    hidden function drawLine(
        dc as Dc, x as Number, base as Number,
        line as String or Null, color as Number
    ) as Number {
        if (line == null) { return base; }

        var font = FaceFonts.label();
        tracked(dc, x, base, font, line, color, 1, Graphics.TEXT_JUSTIFY_LEFT);
        return base + dc.getFontHeight(font) + LINE_GAP;
    }

    hidden function vitals(m as Metrics) as String or Null {
        var parts = [] as Array<String>;
        if (m.recoveryHours != null) { parts.add(m.recoveryHours.format("%d") + "h recovery"); }
        if (m.heartRate != null) { parts.add(m.heartRate.format("%d") + " bpm"); }
        return join(parts);
    }

    // Same rule as the other layout: a recovery clock outranks the
    // weather, and the line takes only what the margin will carry.
    hidden function ambient(dc as Dc, m as Metrics, room as Number) as String or Null {
        var parts = [] as Array<String>;
        if (m.temperature != null) { parts.add(m.temperature.format("%d") + "°F"); }
        var sun = m.sunString();
        if (sun != null) { parts.add((m.sunIsRise ? "sunrise " : "sunset ") + sun); }
        if (m.watchBattery != null) { parts.add(m.watchBattery.format("%d") + "%"); }
        if (parts.size() == 0) { return null; }

        var line = fitJoin(dc, FaceFonts.label(), parts, room, 1);
        return line.equals("") ? null : line;
    }

    hidden function join(parts as Array<String>) as String or Null {
        if (parts.size() == 0) { return null; }

        var line = parts[0];
        for (var i = 1; i < parts.size(); i += 1) {
            line = line + "  ·  " + parts[i];
        }
        return line;
    }
}
