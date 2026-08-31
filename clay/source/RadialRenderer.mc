import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Layout D — Radial. One dial, one page of type, one level row.
//
// The big dial is the step goal. It sweeps clockwise from eight o'clock,
// over the top, to four, and it climbs a gradient as it goes rather than
// filling in a flat colour — the ramp is what says how far along the day
// is at a glance, before a single figure has been read.
//
// Reaching the goal does not end it. At 100% the dial drops back to a
// ghost of the lap it just finished and starts again from the far end,
// running backward toward the start, lit hotter. A day at 160% is then
// visibly a different picture from a day at 60%, which a bar that simply
// tops out cannot manage.
//
// Overpainting the finished lap was tried first and fails: a full arc
// getting slightly brighter has no moving boundary, and nothing about it
// reads as motion. The second pass needs a leading edge of its own.
//
// There is no third pass. Past 200% the dial holds. A third alternating
// direction reads as a machine rather than a face, and 3x goal is rare
// enough that it does not need its own event.
//
// Centred in that gap, clear of the ring's ends on both sides, is a
// second and much shorter dial: the countdown to the next sun event, with
// its clock time set inside it. It runs on whichever span the watch is
// in, filling toward sunset through the day and toward sunrise after
// dusk, and it is painted as the sky rather than as a bar.
//
// The step ramp's colour carries training status, and the status word is
// set to agree with it. The sun dial is the sky and is nobody's accent.
class RadialRenderer extends Renderer {

    // Inset measured off the comp: the dial sits a clear margin inside
    // the rim rather than hugging it. Pushed to the edge it reads as a
    // bezel and the face loses the ring of dark that frames it.
    hidden const ARC_INSET   = 36;

    // Track and lit run at the SAME weight. Only colour separates the goal
    // spent from the goal left — a thinner track would say the remaining
    // steps matter less, which is the opposite of the point.
    //
    // Both rings run at this weight. Thinning the sun dial to rank it
    // below the step ring was tried and reverted: the two gauges are the
    // same instrument seen at two scales, and unequal pens made the small
    // one look like a leftover rather than a second reading.
    hidden const ARC_WIDTH   = 10;
    hidden const SUN_WIDTH   = 10;

    // Eight o'clock, clockwise, to four o'clock: 246° of dial and a 114°
    // gap across the bottom. Both figures are measured off the comp, not
    // chosen — a wider sweep looked closer to the drawing at a glance but
    // ran the arc's ends straight through the row of figures. Garmin
    // measures degrees counter-clockwise from 3 o'clock, so clockwise is a
    // decreasing angle and the dial runs 213 down to -33.
    hidden const DIAL_FROM   = 213.0;
    hidden const DIAL_SPAN   = 246.0;

    // Degrees per sub-arc on the step ramp. A seam budget, not a
    // preference: the widest climb in the palette is about 137 values
    // across the arc, so 2° is roughly one value of change per step —
    // under what the eye resolves at this contrast. The ghost pass carries
    // far less contrast and can run coarser.
    hidden const SEG         = 2;
    hidden const GHOST_SEG   = 4;

    // Where MID — the ramp's signature tone — sits along the dial.
    //
    // The stops are the spec's own table and are NOT re-spaced by
    // luminance. That was tried: it gives a mathematically even climb and
    // a stronger gradient, but it walks the palette away from the drawn
    // reference, which is the thing being matched.
    hidden const ANCHOR      = 0.55;

    // The band of the ramp the status word is set across. Narrow on
    // purpose — the word has to read as one colour that belongs to the
    // dial, with just enough travel to feel lit rather than printed.
    hidden const WORD_FROM   = 0.50;
    hidden const WORD_TO     = 0.80;

    // How much of the finished lap survives underneath the second pass.
    // Clearing to bare track was tried and is more dramatic, but then the
    // ring holds visibly LESS ink at 105% than at 95%, which reads as
    // losing ground. The ghost keeps the completed lap on the face and
    // still leaves the new pass all the contrast it needs.
    hidden const GHOST_MIX   = 0.78;

    // The gap, centred on six o'clock.
    hidden const GAP_MID     = 270.0;
    hidden const GAP_SPAN    = 114.0;

    // The sun dial sits inside that gap and is deliberately much shorter
    // than it, so the sequence around the rim reads arc, gap, small
    // arc, gap, arc. Filling the whole gap closed the ring and the two
    // gauges read as one broken circle instead of two separate things.
    hidden const SUN_SPAN    = 44.0;

    // The sky, as three stops the dial ramps between. Two versions of
    // each daylight colour: what the sky does when it is clear, and what
    // it does under full cloud. Cloudiness mixes between them, so an
    // overcast afternoon really does read grey and a clear sunset really
    // does burn.
    // This dial is a picture of the sky, and a desaturated sky is just a
    // grey bar, so every stop carries real colour.
    //
    // The COVERED stops matter more than they look: cloudiness mixes each
    // daylight stop toward its overcast version, and typical weather sits
    // around 0.7, so what is actually on screen most days is mostly these
    // and barely the clear ones. Overcast is therefore a SLATE BLUE and a
    // banked sunset keeps its warmth — neutral grey here drained the dial
    // whenever the sky was anything short of perfect.
    hidden const SKY_CLEAR    = 0x2E90E6 as Number;   // open blue
    hidden const SKY_COVERED  = 0x5E86A8 as Number;   // overcast, still sky
    hidden const DUSK_CLEAR   = 0xFF6B2E as Number;   // a sunset worth watching
    hidden const DUSK_COVERED = 0xC2764F as Number;   // the sun going down behind cloud
    hidden const NIGHT        = 0x232C63 as Number;   // deep indigo, off the floor

    // The ramp is stepped along the arc a pixel at a time rather than
    // built from flat sub-arcs. drawArc takes WHOLE degrees, so a
    // segmented gradient cannot be subdivided below one degree — which
    // at this radius is a 3px band, and at the 2 degrees it started on,
    // a 7px one. Both step visibly.
    //
    // Walking the arc and stamping an overlapping dot per pixel gives a
    // colour change every pixel instead, and rounds the ends for free.
    // 2px, not 1. At one dot per pixel the sun dial cost ~70ms of a
    // ~109ms frame — two thirds of the whole face for one small gauge.
    // The dots are 9px across, so at 2px spacing they still overlap by 7
    // and the ramp stays smooth; it is the same picture for half the work.
    hidden const SUN_STEP_PX    = 2.0;

    // During the wrist-raise reveal the ramp runs coarse. The face is
    // being redrawn every frame there and the gradient is not what the
    // eye is following — the bead is. The full ramp lands on the frame
    // that settles.
    hidden const SUN_STEP_DRAG  = 6.0;

    hidden const BEAD_R      = 7;

    // Vertical rhythm, as baselines. Every one of these is a measurement
    // taken off the approved comp and scaled to the screen, not a value
    // that felt right — the comp's whole argument is the air between the
    // elements, and that air is what a guessed fraction loses first.
    //
    // Expressed as fractions of the height so the layout survives a
    // device of another size.
    hidden const DATE_Y      = 0.248;
    hidden const TEMP_Y      = 0.305;
    hidden const TIME_BASE_Y = 0.535;
    hidden const STATUS_Y    = 0.608;
    hidden const VALUE_Y     = 0.758;
    hidden const LABEL_Y     = 0.805;
    hidden const SUN_Y       = 0.893;

    // Tracking. The words on this face are all set small and wide; the
    // open letterspacing is doing the work that size does everywhere
    // else, and it is the difference between a caption and a label.
    // Solved, not chosen: the comp's set widths minus the natural
    // advance of the face, divided over the gaps. The row's units come
    // out at zero — the comp's label spacing is the typeface's own, and
    // opening it further was making SUNSET a third wider than drawn.
    hidden const TRACK_DATE   = 4;
    hidden const TRACK_STATUS = 4;
    hidden const TRACK_LABEL  = 1;

    // Column centres for the three-up row, as fractions of the width.
    hidden const COL_L       = 0.303;
    hidden const COL_M       = 0.50;
    hidden const COL_R       = 0.706;

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

        drawDial(dc, m, cx, cy, r, t);
        drawSunDial(dc, m, cx, cy, r, t);

        drawDate(dc, m, cx, h);
        drawTemp(dc, m, cx, h);
        drawTime(dc, m, cx, h);
        drawStatus(dc, m, cx, h);

        drawRow(dc, m, w, h);
        drawSunTime(dc, m, cx, h);
    }

    // Track first, always, across the whole span — the unlit remainder is
    // part of the reading. Then whichever pass the day is on.
    //
    // Nothing is drawn at all on a watch that cannot say what the goal is.
    // An empty track is a gauge reading zero, which is not the same thing
    // as silence.
    hidden function drawDial(
        dc as Dc, m as Metrics,
        cx as Number, cy as Number, r as Number, t as Float
    ) as Void {
        var progress = m.stepProgress();
        if (progress == null) { return; }

        var p = progress as Float;
        var stops = Theme.ramp(status);

        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        arc(dc, cx, cy, r, DIAL_FROM, DIAL_SPAN, Theme.TRACK_DIAL, ARC_WIDTH);

        // The ramp is over a hundred sub-arcs and the reveal would run it
        // on every frame of the wrist raise. Animate a flat MID and pay for
        // the gradient once, on the frame that settles.
        var lap1 = p > 1.0 ? 1.0 : p;
        if (t < 1.0) {
            arc(dc, cx, cy, r, DIAL_FROM, DIAL_SPAN * lap1 * t, stops[1], ARC_WIDTH);
            return;
        }

        var lap2 = p - 1.0;
        if (lap2 < 0.0) { lap2 = 0.0; }
        if (lap2 > 1.0) { lap2 = 1.0; }

        if (lap2 <= 0.0) {
            ramp(dc, cx, cy, r, DIAL_FROM, DIAL_SPAN * lap1,
                stops, 0.0, SEG, false, 0.0);
            return;
        }

        // The lap just finished, held as a record rather than wiped.
        ramp(dc, cx, cy, r, DIAL_FROM, DIAL_SPAN,
            stops, 0.0, GHOST_SEG, false, GHOST_MIX);

        // Lift opens high rather than at zero, so the reverse pass is
        // obviously a hotter run from its very first degree instead of
        // spending the early part of it looking like the lap before.
        var shine = Theme.rampCap(status) * (0.45 + (0.55 * lap2));
        if (shine > 1.0) { shine = 1.0; }

        // It occupies the far end of the dial and grows back toward
        // DIAL_FROM, so its leading edge travels against the first lap.
        var back = DIAL_SPAN * lap2;
        ramp(dc, cx, cy, r, DIAL_FROM - DIAL_SPAN + back, back,
            stops, shine, SEG, true, 0.0);
    }

    // One run of the gradient, laid down as flat sub-arcs — Connect IQ has
    // no gradient primitive, so `blend` and a lot of small arcs is the
    // whole toolkit.
    //
    // Colour is a function of angular POSITION on the dial, never of how
    // much is filled. A given degree is always the same colour and filling
    // up walks through the ramp; keying colour to the fill fraction
    // instead would re-tint the entire arc on every step taken.
    //
    // `mirror` flips that mapping for the second pass, putting DEEP at the
    // far end where the pass began so the ramp climbs toward the edge that
    // is actually moving. Without it the second lap gets DARKER as it
    // progresses, because the gradient is pinned to the dial and the pass
    // runs against it.
    hidden function ramp(
        dc as Dc,
        cx as Number, cy as Number, r as Number,
        fromDeg as Float, sweep as Float,
        stops as Array<Number>, shine as Float,
        seg as Number, mirror as Boolean, ghost as Float
    ) as Void {
        if (sweep < 0.5) { return; }

        // Set the pen once. Renderer.arc() resets it to 1 on every call,
        // which is the reason the ramp does not go through it.
        dc.setPenWidth(ARC_WIDTH);

        // Walk INTEGER degree boundaries and sample the ramp at the true
        // fractional position between them. Stepping in floats and letting
        // drawArc truncate gives uneven segments and 1px seams.
        var a = fromDeg.toNumber();
        var last = Math.floor(fromDeg - sweep).toNumber();

        while (a > last) {
            var b = a - seg;
            if (b < last) { b = last; }
            if (b == a) { break; }          // a full ring, not a segment

            // One degree of overlap so no seam opens between segments.
            var to = b - 1;
            if (to < last) { to = last; }

            dc.setColor(
                rampAt(((a + b) / 2.0), stops, shine, mirror, ghost),
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, wrap(a), wrap(to));
            a = b;
        }

        dc.setPenWidth(1);

        // drawArc butts its ends. Both ends of the run get a disc the width
        // of the pen, placed at the run's TRUE float angles so the run
        // reaches its exact length — the body of it can only land on whole
        // degrees.
        endCap(dc, cx, cy, r, fromDeg, stops, shine, mirror, ghost);
        endCap(dc, cx, cy, r, fromDeg - sweep, stops, shine, mirror, ghost);
    }

    // The ramp, sampled at a position along it. 0.0 is DEEP, ANCHOR is
    // MID, 1.0 is PALE — lifted toward MILK as `shine` rises.
    hidden function rampColour(
        along as Float, stops as Array<Number>, shine as Float
    ) as Number {
        var mid  = stops[1];
        var foot = blend(stops[0], mid, 0.34 * shine);
        var top  = blend(stops[2], stops[3], shine);

        var a = along;
        if (a < 0.0) { a = 0.0; }
        if (a > 1.0) { a = 1.0; }

        return a < ANCHOR
            ? blend(foot, mid, a / ANCHOR)
            : blend(mid, top, (a - ANCHOR) / (1.0 - ANCHOR));
    }

    // The ramp, sampled at an absolute angle on the dial.
    hidden function rampAt(
        deg as Float,
        stops as Array<Number>, shine as Float,
        mirror as Boolean, ghost as Float
    ) as Number {
        var along = (DIAL_FROM - deg) / DIAL_SPAN;
        if (mirror) { along = 1.0 - along; }

        var colour = rampColour(along, stops, shine);
        return ghost > 0.0 ? blend(colour, Theme.TRACK_DIAL, ghost) : colour;
    }

    hidden function endCap(
        dc as Dc,
        cx as Number, cy as Number, r as Number, deg as Float,
        stops as Array<Number>, shine as Float,
        mirror as Boolean, ghost as Float
    ) as Void {
        dc.setColor(
            rampAt(deg, stops, shine, mirror, ghost),
            Graphics.COLOR_TRANSPARENT
        );
        dc.fillCircle(cx + polarX(r, deg), cy + polarY(r, deg), ARC_WIDTH / 2);
    }

    // drawArc wants its angles in 0-360; the dial is walked unwrapped so
    // that "degrees along" stays a plain subtraction.
    hidden function wrap(deg as Number) as Number {
        var d = deg;
        while (d < 0) { d += 360; }
        while (d >= 360) { d -= 360; }
        return d;
    }

    // The sun: a short second dial centred at six o'clock, standing clear
    // of the step ring's ends with open space either side.
    //
    // It is painted as the sky the wearer is heading into, not as a bar.
    // Through the day the ramp runs from the sky's current colour,
    // through sunset, into night; through the night it runs the same
    // three stops backwards, out of night through dawn into daylight.
    // A bead rides it at the current position, turning clockwise like the
    // ring above it.
    //
    // This is the one place the face carries colour that is neither the
    // training ramp nor the accent. It is a picture of the sky rather than
    // a reading encoded in hue, but it is a real exception and worth
    // keeping an eye on.
    hidden function drawSunDial(
        dc as Dc, m as Metrics,
        cx as Number, cy as Number, r as Number, t as Float
    ) as Void {
        var f = m.sunProgress();
        if (f == null) { return; }

        // No weather reads as clear sky, not as overcast. A watch out of
        // phone range should not paint a grey day.
        var cloud = m.cloudiness == null ? 0.0 : m.cloudiness as Float;
        var sky = blend(SKY_CLEAR, SKY_COVERED, cloud);
        var dusk = blend(DUSK_CLEAR, DUSK_COVERED, cloud);

        // Which way the sky is going. `sunIsRise` means the next event is
        // sunrise, so the span being drawn is the night and the ramp runs
        // the other way: out of night, through dawn, into daylight.
        var c0 = m.sunIsRise ? NIGHT : sky;   // where the span began
        var c2 = m.sunIsRise ? sky : NIGHT;   // where it is going

        // The ramp turns the same way the big ring does — clockwise, which
        // along the bottom of the face means right to left. Both gauges
        // sweep as one continuous motion around the rim.
        //
        // Garmin measures degrees counter-clockwise from three o'clock, so
        // clockwise is a DECREASING angle: the ramp starts at the dial's
        // right-hand end and walks down to its left.
        var from = GAP_MID + (SUN_SPAN / 2.0);

        // One dot per pixel of arc length, each a step further along the
        // ramp. The dots are as wide as the pen and land a pixel apart,
        // so they fuse into a smooth stroke.
        var length = (SUN_SPAN / 360.0) * 2.0 * Math.PI * r;
        var dots = (length / (t < 1.0 ? SUN_STEP_DRAG : SUN_STEP_PX)).toNumber();
        if (dots < 2) { dots = 2; }
        var dotR = SUN_WIDTH / 2;

        for (var i = 0; i <= dots; i += 1) {
            var v = i.toFloat() / dots.toFloat();
            var colour = v < 0.5
                ? blend(c0, dusk, v * 2.0)
                : blend(dusk, c2, (v - 0.5) * 2.0);

            var deg = from - (SUN_SPAN * v);
            dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + polarX(r, deg), cy + polarY(r, deg), dotR);
        }

        drawSunBead(dc, m, cx, cy, r, from - (SUN_SPAN * f * t));
    }

    hidden function drawSunBead(
        dc as Dc, m as Metrics,
        cx as Number, cy as Number, r as Number, deg as Float
    ) as Void {
        var bx = cx + polarX(r, deg);
        var by = cy + polarY(r, deg);

        dc.setColor(Theme.bg(dark, status), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, BEAD_R + 2);
        dc.setColor(fg(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, BEAD_R - 1);
    }

    // The time the dial is counting to, set inside it, with a triangle
    // for which event it is. The word would not fit and would not add
    // anything the triangle does not already say.
    hidden function drawSunTime(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        var value = m.sunString();
        if (value == null) { return; }

        var font = FaceFonts.sansMicro();
        var base = (h * SUN_Y).toNumber();
        var width = 14 + trackedWidth(dc, font, value, TRACK_LABEL);
        var left = cx - (width / 2);

        sunMark(dc, left + 4, base, m.sunIsRise, secondary());
        tracked(dc, left + 14, base, font, value, secondary(),
            TRACK_LABEL, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Upper case throughout, which is the other half of why the small
    // type on this face reads as labelling rather than as text. Lower
    // case is the editorial layouts' voice; borrowing it here just made
    // the same words look softer and less deliberate.
    hidden function drawDate(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        tracked(
            dc, cx, (h * DATE_Y).toNumber(), FaceFonts.sansLabel(),
            m.dateLineLong.toUpper(), secondary(),
            TRACK_DATE, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // Temperature rides under the date as a subtitle rather than down in
    // the row. It belongs with the date: both are conditions the wearer
    // is in rather than readings off the wearer, and pairing them frees
    // the row to be three body numbers that scan as one set.
    hidden function drawTemp(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        if (m.temperature == null) { return; }

        tracked(
            dc, cx, (h * TEMP_Y).toNumber(), FaceFonts.sansMicro(),
            m.temperature.format("%d") + "°F", tertiary(),
            TRACK_LABEL, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // Never animated. The time is the reason the screen came on; making
    // it arrive late is a tax on every wrist raise.
    //
    // Set on its own measured baseline rather than centred on the face.
    // Optical centring put it in the middle of the disc, but the comp
    // sits it a little high — the row and the sun dial below need more
    // room than the date above, and the time has to move up to give it.
    hidden function drawTime(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        baseline(
            dc, cx, (h * TIME_BASE_Y).toNumber(), FaceFonts.sansTime(),
            m.timeString(), fg(), Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // The word that explains the colour. Without it the palette is just
    // a mood; with it, the colour is a reading.
    //
    // It is set in the dial's own ramp rather than in the accent, so the
    // word and the graphic are the same colour — two things claiming to
    // mean "productive" in two different greens was the face arguing with
    // itself. A slight climb runs across the letters, the same climb the
    // dial makes, which ties the two together without turning the word
    // into a second gauge.
    hidden function drawStatus(
        dc as Dc, m as Metrics, cx as Number, h as Number
    ) as Void {
        if (m.trainingLabel == null) { return; }

        rampText(
            dc, cx, (h * STATUS_Y).toNumber(), FaceFonts.sansLabel(),
            (m.trainingLabel as String).toUpper(), Theme.ramp(status),
            TRACK_STATUS
        );
    }

    // Centred, letterspaced, and stepped along the ramp one glyph at a
    // time. Connect IQ has no gradient fill for text either, so per-glyph
    // is as fine as this gets — which is enough at this size, because the
    // letters are the sampling grid the eye already sees.
    hidden function rampText(
        dc as Dc,
        cx as Number, baseY as Number,
        font as FontType, value as String,
        stops as Array<Number>, extra as Number
    ) as Void {
        var n = value.length();
        if (n == 0) { return; }

        var left = cx - (trackedWidth(dc, font, value, extra) / 2);
        var y = baseY - Graphics.getFontAscent(font);

        for (var i = 0; i < n; i += 1) {
            var ch = value.substring(i, i + 1) as String;
            var v = n < 2 ? 0.5 : i.toFloat() / (n - 1).toFloat();

            dc.setColor(
                rampColour(WORD_FROM + ((WORD_TO - WORD_FROM) * v), stops, 0.0),
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawText(left, y, font, ch, Graphics.TEXT_JUSTIFY_LEFT);
            left += dc.getTextWidthInPixels(ch, font) + extra;
        }
    }

    // Three groups, each a figure over its unit. Every value sits on one
    // baseline and every label on a second, so the row stays level even
    // though the three are set in different faces — that shared pair of
    // baselines is the whole reason the row reads as organised rather
    // than as three things that happen to be near each other.
    //
    // A group with nothing behind it is dropped and the others keep
    // their columns. Re-centring the survivors would move the temperature
    // every time the weather cache expired.
    hidden function drawRow(
        dc as Dc, m as Metrics, w as Number, h as Number
    ) as Void {
        var valueBase = (h * VALUE_Y).toNumber();
        var labelBase = (h * LABEL_Y).toNumber();
        var valueFont = FaceFonts.sansSmall();
        var labelFont = FaceFonts.sansMicro();

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
        baseline(dc, cx, valueBase, valueFont, value, fg(),
            Graphics.TEXT_JUSTIFY_CENTER);
        tracked(dc, cx, labelBase, labelFont, label, secondary(),
            TRACK_LABEL, Graphics.TEXT_JUSTIFY_CENTER);
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
