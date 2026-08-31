import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Recon - a graduated bezel and a block of readouts.
//
// This is Clay's Radial layout taken apart and rebuilt out of hard
// edges. The composition is deliberately the same, because the
// composition was measured off an approved comp and is not what felt
// soft: date, temperature under it, the time large and centred, the
// status word, a three-up row of body figures, and the next sun event
// at six o'clock. Every baseline below is Clay's, carried over
// unchanged.
//
// What changed is everything about HOW it is drawn:
//
//   Clay's dial is one continuous arc with rounded caps, filled with a
//   four-stop gradient. Recon's is a SCALE - 120 graduations at 3
//   degrees, majors every 30, square-ended, and the reading is which
//   ones are lit. A gradient says "somewhere around here"; a graduation
//   says a number. That swap is most of the difference between the two
//   faces, and it is why the ramp code, the per-glyph gradient text and
//   the dot-stamped sky dial are all gone rather than restyled.
//
//   Clay's sun dial paints the sky as a colour ramp. Recon prints the
//   time the sun goes down. The sky is a mood; the time is a fact.
//
//   Clay carries nine accent ramps. Recon carries three signals. See
//   Theme.
//
// The one behaviour kept whole is the step overshoot, because it is the
// one thing on Clay that encodes something a bar cannot. At 100% the
// lit graduations drop to a spent version of the signal and a second
// pass starts from the far end running backward at full brightness, so
// 160% is a visibly different picture from 60%. There is no third pass.
class BezelFace {

    // ---- The bezel -------------------------------------------------
    //
    // Graduations run the FULL circle even though the gauge only spans
    // 246 degrees of it. The ring is structure first and a gauge second:
    // a scale that stops where the reading stops looks like a broken
    // arc, where a complete one looks like an instrument that happens to
    // be reading over part of its range.
    hidden const RIM_INSET   = 5;
    hidden const MINOR_LEN   = 8;
    hidden const MAJOR_LEN   = 17;
    hidden const MINOR_W     = 2;
    hidden const MAJOR_W     = 4;

    // 3 degrees, so 120 graduations. Six was tried first - the classic
    // chronograph count of 60 - and at this radius it leaves 22px
    // between ticks, which reads as a row of marks rather than as a
    // scale that can fill. At 3 degrees they sit 11px apart and the lit
    // run reads as a bar you can still count.
    hidden const MINOR_STEP  = 3;
    hidden const MAJOR_EVERY = 30;

    // Eight o'clock, clockwise, over the top, to four: 246 degrees of
    // gauge and a 114 degree gap across the bottom for the sun readout.
    // Both figures are Clay's, measured off the comp - a wider sweep
    // looks closer to the drawing at a glance but runs the ends of the
    // gauge straight through the row of figures.
    //
    // Garmin measures degrees counter-clockwise from 3 o'clock, so
    // clockwise is a DECREASING angle: the gauge runs 213 down to -33.
    hidden const DIAL_FROM   = 213.0;
    hidden const DIAL_SPAN   = 246.0;

    // Both ends of the gauge's range, drawn long and lit even when
    // nothing is reading against them. They are the scale's endstops -
    // without them the gauge has no visible zero, and a reading of zero
    // is indistinguishable from an instrument that is switched off.
    // Both land on the 3 degree grid, which is why the grid starts at 0.
    hidden const STOP_A      = 213;
    hidden const STOP_B      = 327;

    // ---- The reticle -----------------------------------------------
    //
    // Four corner brackets around the TIME only, not around the whole
    // readout block. Framing everything was drawn first and its bottom
    // corners fouled the graduations - that box's half-diagonal is
    // larger than the ring's inner radius, so there is nowhere for it to
    // go. Framing the clock alone is also the better call: it marks the
    // one thing on the face you are actually aiming at.
    hidden const BOX_L       = 0.205;
    hidden const BOX_R       = 0.795;
    hidden const BOX_T       = 0.355;
    hidden const BOX_B       = 0.565;
    hidden const BOX_ARM     = 20;
    hidden const BOX_W       = 2;

    // A single hairline between the identity block and the readouts.
    // Dim enough to be structure rather than an element.
    hidden const RULE_Y      = 0.665;
    hidden const RULE_HALF   = 0.26;

    // ---- Vertical rhythm -------------------------------------------
    //
    // Every one of these is Clay's, and Clay's are measurements taken
    // off the approved comp rather than values that felt right. The
    // comp's whole argument is the air between the elements, and that
    // air is the first thing a guessed fraction loses. Expressed as
    // fractions of the height so the layout survives another size.
    hidden const DATE_Y      = 0.248;
    hidden const TEMP_Y      = 0.305;
    hidden const TIME_BASE_Y = 0.535;
    hidden const STATUS_Y    = 0.608;
    hidden const VALUE_Y     = 0.758;
    hidden const LABEL_Y     = 0.805;
    hidden const SUN_Y       = 0.893;

    // Column centres for the three-up row, as fractions of the width.
    hidden const COL_L       = 0.303;
    hidden const COL_M       = 0.50;
    hidden const COL_R       = 0.706;

    // Tracking. Wider than Clay's 4/4/1, because Bahnschrift Condensed
    // is a much narrower face and the same numbers left the words
    // looking cramped rather than issued. Open letterspacing on small
    // caps is what makes them read as stencilled labelling.
    hidden const TRACK_DATE   = 6;
    hidden const TRACK_STATUS = 7;
    hidden const TRACK_LABEL  = 2;

    hidden var status as Number = Theme.STATUS_NONE;

    function initialize() {
    }

    function draw(dc as Dc, m as Metrics, reveal as Float) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w / 2) - RIM_INSET;
        var t = eased(reveal);

        status = m.trainingStatus;

        dc.setColor(Graphics.COLOR_TRANSPARENT, Theme.ground(status));
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        drawBezel(dc, m, cx, cy, r, t);

        drawReticle(dc, w, h);
        drawRule(dc, w, h);

        drawDate(dc, m, cx, h);
        drawTemp(dc, m, cx, h);
        drawTime(dc, m, cx, h);
        drawStatus(dc, m, cx, h);

        drawRow(dc, m, w, h);
        drawSun(dc, m, cx, h);
    }

    // Always-on state for burn-in-protected screens. At 1% brightness
    // with a pixel budget there is no layout left to express, only the
    // time - so the bezel, the reticle and every readout are dropped
    // rather than dimmed.
    function drawAmbient(dc as Dc, m as Metrics) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Theme.GROUND);
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

        text(dc, x, y, font, m.timeString(), Theme.AMBIENT,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ------------------------------------------------------------------
    // The scale.
    //
    // One pass over 120 graduations, each asking what colour it is. The
    // structural colour is a function of the angle alone and the lit
    // colour is a function of how far along the gauge that angle sits,
    // so nothing here has to be drawn twice or painted over.
    //
    // The whole ring costs 120 drawLine calls. Clay's equivalent was a
    // 123-segment gradient plus ~147 fillCircles for the sky dial, and
    // fillCircle is the expensive one - the sun dial alone was two
    // thirds of Clay's frame. There is no reason to run this coarse
    // during the reveal.
    hidden function drawBezel(
        dc as Dc, m as Metrics,
        cx as Number, cy as Number, r as Number, t as Float
    ) as Void {
        var progress = m.stepProgress();

        // Nothing to read is not the same as reading zero. The scale is
        // structure and is drawn either way, but on a watch that cannot
        // say what the goal is NO graduation lights - not even the one
        // on the zero mark.
        //
        // That distinction has to be carried explicitly rather than by
        // letting a null fall through to 0.0. It did fall through at
        // first, and because the endstop sits exactly at zero degrees
        // along the gauge it satisfied `along <= lit1` at 0 <= 0 and lit
        // in the signal colour. A watch with no step data was drawing a
        // gauge that read zero, which is a claim it cannot back.
        var reading = progress != null;
        var p = reading ? (progress as Float) * t : 0.0;

        var lap1 = p > 1.0 ? 1.0 : p;
        var lap2 = p - 1.0;
        if (lap2 < 0.0) { lap2 = 0.0; }
        if (lap2 > 1.0) { lap2 = 1.0; }

        var lit1 = DIAL_SPAN * lap1;

        // The second pass occupies the FAR end of the gauge and grows
        // back toward the start, so its leading edge travels against the
        // first lap's. Overpainting the finished lap instead was tried
        // on Clay and fails: a full scale getting slightly brighter has
        // no moving boundary, and nothing about it reads as motion.
        var back = DIAL_SPAN - (DIAL_SPAN * lap2);

        var live = Theme.signal(status);
        var spent = Theme.signalDim(status);

        // Hoisted: the family is fixed for the whole ring and the loop
        // below runs 120 times.
        var sLit = Theme.structLit(status);
        var sMid = Theme.struct(status);
        var sDeep = Theme.structDeep(status);

        for (var d = 0; d < 360; d += MINOR_STEP) {
            var major = (d % MAJOR_EVERY) == 0;
            var stop = (d == STOP_A) || (d == STOP_B);

            // Degrees clockwise from the gauge's start. Anything past
            // DIAL_SPAN is in the gap at the bottom and never lights.
            var along = DIAL_FROM - d;
            while (along < 0.0) { along += 360.0; }
            var onGauge = along <= DIAL_SPAN;

            // Graduations inside the gauge's range sit ONE LEVEL BRIGHTER
            // than the ones outside it, and that difference is load
            // bearing rather than decorative: the unlit remainder is part
            // of the reading. Drawn at a single structural level the
            // whole ring went flat, the range the gauge covers became
            // invisible, and a scale two thirds full looked exactly like
            // a scale that had nothing left to give.
            var colour = major ? sMid : sDeep;
            if (onGauge) { colour = major ? sLit : sMid; }
            if (stop) { colour = sLit; }

            // With a real reading of zero the endstop DOES light, and
            // that is deliberate: an instrument at zero puts its needle
            // on the stop rather than going dark. The difference from
            // the no-data case above is the whole point of `reading`.
            if (onGauge && reading) {
                if (lap2 > 0.0 && along >= back) {
                    colour = live;
                } else if (along <= lit1) {
                    colour = lap2 > 0.0 ? spent : live;
                }
            }

            var len = (major || stop) ? MAJOR_LEN : MINOR_LEN;
            var pen = (major || stop) ? MAJOR_W : MINOR_W;
            tick(dc, cx, cy, r, d.toFloat(), len, pen, colour);
        }

        dc.setPenWidth(1);
    }

    // One graduation: a radial line from the rim inward. drawLine butts
    // its ends, which is the whole point - Clay rounds every cap because
    // its arcs have to read as one continuous stroke, and a scale wants
    // exactly the opposite.
    hidden function tick(
        dc as Dc,
        cx as Number, cy as Number, r as Number,
        deg as Float, len as Number, pen as Number, colour as Number
    ) as Void {
        var rad = deg * Math.PI / 180.0;
        var c = Math.cos(rad);
        var s = Math.sin(rad);
        var inner = r - len;

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawLine(
            cx + (r * c).toNumber(),     cy - (r * s).toNumber(),
            cx + (inner * c).toNumber(), cy - (inner * s).toNumber()
        );
    }

    // ------------------------------------------------------------------
    // Furniture.

    hidden function drawReticle(dc as Dc, w as Number, h as Number) as Void {
        var l = (w * BOX_L).toNumber();
        var rt = (w * BOX_R).toNumber();
        var tp = (h * BOX_T).toNumber();
        var bt = (h * BOX_B).toNumber();

        // Structure on an ordinary day, the warning itself on a bad one.
        // See Theme.frame() for why this is the only element besides the
        // gauge and the status word allowed to carry the signal.
        dc.setColor(Theme.frame(status), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(BOX_W);

        corner(dc, l,  tp,  1,  1);
        corner(dc, rt, tp, -1,  1);
        corner(dc, l,  bt,  1, -1);
        corner(dc, rt, bt, -1, -1);

        dc.setPenWidth(1);
    }

    // An L: one arm along x, one along y, running away from the corner
    // into the box.
    hidden function corner(
        dc as Dc, x as Number, y as Number, sx as Number, sy as Number
    ) as Void {
        dc.drawLine(x, y, x + (BOX_ARM * sx), y);
        dc.drawLine(x, y, x, y + (BOX_ARM * sy));
    }

    hidden function drawRule(dc as Dc, w as Number, h as Number) as Void {
        var half = (w * RULE_HALF).toNumber();
        var y = (h * RULE_Y).toNumber();
        var cx = w / 2;

        dc.setColor(Theme.structDeep(status), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx - half, y, cx + half, y);
    }

    // ------------------------------------------------------------------
    // Readouts. Upper case throughout - nothing on this face is set in
    // lower case, and the subset fonts do not even carry it.

    hidden function drawDate(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        tracked(dc, cx, (h * DATE_Y).toNumber(), FaceFonts.label(),
            m.dateLineLong.toUpper(), Theme.structLit(status),
            TRACK_DATE, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Temperature rides under the date as a subtitle rather than down in
    // the row. It belongs with the date: both are conditions the wearer
    // is in rather than readings off the wearer, and pairing them frees
    // the row to be three body numbers that scan as one set.
    hidden function drawTemp(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        if (m.temperature == null) { return; }

        tracked(dc, cx, (h * TEMP_Y).toNumber(), FaceFonts.micro(),
            m.temperature.format("%d") + "°F", Theme.struct(status),
            TRACK_LABEL, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Never animated. The time is the reason the screen came on; making
    // it arrive late is a tax on every wrist raise.
    hidden function drawTime(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        baseline(dc, cx, (h * TIME_BASE_Y).toNumber(), FaceFonts.time(),
            m.timeString(), Theme.BONE, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The word that explains the signal. Three colours cannot tell
    // peaking from productive, and are not meant to - this line is where
    // that lives. Set flat in the signal colour: Clay steps its status
    // word along a gradient, which is exactly the softness being
    // designed out.
    hidden function drawStatus(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        if (m.trainingLabel == null) { return; }

        tracked(dc, cx, (h * STATUS_Y).toNumber(), FaceFonts.label(),
            (m.trainingLabel as String).toUpper(), Theme.signal(status),
            TRACK_STATUS, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Three groups, each a figure over its unit. Every value sits on one
    // baseline and every label on a second, so the row stays level -
    // that shared pair of baselines is the whole reason it reads as
    // organised rather than as three things that happen to be near each
    // other.
    //
    // A group with nothing behind it is dropped and the others keep
    // their columns. Re-centring the survivors would move the heart rate
    // every time a sensor read came back empty.
    hidden function drawRow(
        dc as Dc, m as Metrics, w as Number, h as Number
    ) as Void {
        var valueBase = (h * VALUE_Y).toNumber();
        var labelBase = (h * LABEL_Y).toNumber();
        var valueFont = FaceFonts.small();
        var labelFont = FaceFonts.micro();

        if (m.heartRate != null) {
            group(dc, (w * COL_L).toNumber(), valueBase, labelBase,
                valueFont, labelFont, m.heartRate.format("%d"), "BPM");
        }

        if (m.bodyBattery != null) {
            group(dc, (w * COL_M).toNumber(), valueBase, labelBase,
                valueFont, labelFont, m.bodyBattery.format("%d"), "BODY");
        }

        var steps = m.stepsShort();
        if (steps != null) {
            group(dc, (w * COL_R).toNumber(), valueBase, labelBase,
                valueFont, labelFont, steps, "STEPS");
        }
    }

    hidden function group(
        dc as Dc,
        cx as Number, valueBase as Number, labelBase as Number,
        valueFont as FontType, labelFont as FontType,
        value as String, label as String
    ) as Void {
        baseline(dc, cx, valueBase, valueFont, value, Theme.BONE,
            Graphics.TEXT_JUSTIFY_CENTER);
        tracked(dc, cx, labelBase, labelFont, label, Theme.structLit(status),
            TRACK_LABEL, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The next sun event, printed, in the gap at six o'clock. Clay draws
    // a second small dial here and paints it as the sky - a gradient
    // from daylight through dusk into night, stamped one disc per pixel
    // of arc. It is the prettiest thing on that face and it costs two
    // thirds of the frame.
    //
    // Recon prints the time instead. A triangle says which event; the
    // figure says when. Nothing here is a picture of anything.
    hidden function drawSun(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        var value = m.sunString();
        if (value == null) { return; }

        var font = FaceFonts.micro();
        var base = (h * SUN_Y).toNumber();
        var width = 14 + trackedWidth(dc, font, value, TRACK_LABEL);
        var left = cx - (width / 2);

        sunMark(dc, left + 4, base, m.sunIsRise, Theme.structLit(status));
        tracked(dc, left + 14, base, font, value, Theme.BONE_DIM,
            TRACK_LABEL, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // A small solid triangle, up for the next sunrise and down for the
    // next sunset. Drawn rather than set, because the subset font
    // carries no arrow glyphs and adding two would cost more than the
    // shape does.
    hidden function sunMark(
        dc as Dc, cx as Number, baseY as Number, up as Boolean, colour as Number
    ) as Void {
        var w = 5;
        var hh = 6;
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        if (up) {
            dc.fillPolygon([[cx, baseY - hh], [cx - w, baseY], [cx + w, baseY]]);
        } else {
            dc.fillPolygon([[cx, baseY], [cx - w, baseY - hh], [cx + w, baseY - hh]]);
        }
    }

    // ------------------------------------------------------------------
    // Type helpers.

    hidden function text(
        dc as Dc, x as Number, y as Number, font as FontType,
        value as String, colour as Number, justify as TextJustification
    ) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, value, justify);
    }

    // Draws with the baseline at baseY rather than the top of the line
    // box, so runs set in different sizes can share a baseline.
    hidden function baseline(
        dc as Dc, x as Number, baseY as Number, font as FontType,
        value as String, colour as Number, justify as TextJustification
    ) as Void {
        text(dc, x, baseY - Graphics.getFontAscent(font), font, value,
            colour, justify);
    }

    // Letterspaced text, drawn a character at a time. Connect IQ has no
    // tracking control, so this is the only way to open it.
    hidden function tracked(
        dc as Dc, x as Number, baseY as Number, font as FontType,
        value as String, colour as Number, extra as Number,
        justify as TextJustification
    ) as Void {
        var width = trackedWidth(dc, font, value, extra);
        var left = x;
        if (justify == Graphics.TEXT_JUSTIFY_CENTER) {
            left = x - (width / 2);
        }

        var y = baseY - Graphics.getFontAscent(font);
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < value.length(); i += 1) {
            var ch = value.substring(i, i + 1) as String;
            dc.drawText(left, y, font, ch, Graphics.TEXT_JUSTIFY_LEFT);
            left += dc.getTextWidthInPixels(ch, font) + extra;
        }
    }

    hidden function trackedWidth(
        dc as Dc, font as FontType, value as String, extra as Number
    ) as Number {
        if (value.length() == 0) { return 0; }
        return dc.getTextWidthInPixels(value, font) + (extra * (value.length() - 1));
    }

    // Cheap ease-out. Real alpha blending is not available, so the wake
    // animation eases how far the scale has lit rather than opacity.
    hidden function eased(reveal as Float) as Float {
        var t = reveal;
        if (t < 0.0) { t = 0.0; }
        if (t > 1.0) { t = 1.0; }
        return 1.0 - ((1.0 - t) * (1.0 - t));
    }
}
