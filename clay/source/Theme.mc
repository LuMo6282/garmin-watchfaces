import Toybox.Graphics;
import Toybox.Lang;

// The palette is a function of training status.
//
// The face still shows exactly one accent at a time - that rule has not
// been relaxed, it has been given a job. The accent now says how your
// training is going, so the colour is information rather than decoration,
// and the face reads differently in a peak week than in a recovery one.
//
// Grounds stay near-black on this AMOLED panel and are only tinted a few
// percent toward the accent's hue. Anything more costs battery, risks
// burn-in, and stops the cream type sitting cleanly on top.
module Theme {

    enum {
        STATUS_NONE = 0,
        STATUS_DETRAINING,
        STATUS_RECOVERY,
        STATUS_MAINTAINING,
        STATUS_PRODUCTIVE,
        STATUS_PEAKING,
        STATUS_UNPRODUCTIVE,
        STATUS_STRAINED,
        STATUS_OVERREACHING
    }

    // Accent on the dark treatment.
    //
    // No-status resolves to clay rather than to a neutral. A watch that
    // has not earned a training status yet is the normal state for the
    // first week, on a rest block, and any time the history lapses - and
    // a bone accent made all of those look like a face with its colour
    // broken rather than a face with nothing to report. Clay is the
    // signature, so it is what the face falls back to; the status WORD
    // is what disambiguates, and it is simply absent when unknown.
    const A_NONE_D        = 0xD97757 as Number;   // clay - the resting identity
    const A_DETRAINING_D  = 0x7C8894 as Number;   // cold steel, the face cools off
    const A_RECOVERY_D    = 0x6FB0A6 as Number;   // teal, the only calm state
    const A_MAINTAINING_D = 0xC0925E as Number;   // bronze, steady
    const A_PRODUCTIVE_D  = 0xD97757 as Number;   // clay, the signature
    const A_PEAKING_D     = 0xF2A93B as Number;   // gold, rare and lit
    const A_UNPRODUCTIVE_D= 0x9A82AE as Number;   // dusty violet, something is off
    const A_STRAINED_D    = 0xD9575A as Number;   // alarm red, back off
    const A_OVERREACH_D   = 0xE08A6E as Number;   // scorched clay, one step short of strain

    // Accent on the light treatment - same hues, taken down far enough
    // to hold their own against cream.
    const A_NONE_L        = 0xB0512D as Number;
    const A_DETRAINING_L  = 0x4E5A66 as Number;
    const A_RECOVERY_L    = 0x35786F as Number;
    const A_MAINTAINING_L = 0x8A6234 as Number;
    const A_PRODUCTIVE_L  = 0xB0512D as Number;
    const A_PEAKING_L     = 0xA96F06 as Number;
    const A_UNPRODUCTIVE_L= 0x6E5583 as Number;
    const A_STRAINED_L    = 0xAE3134 as Number;
    const A_OVERREACH_L   = 0xA85434 as Number;

    // Grounds, tinted toward the accent by a few percent.
    const G_NONE          = 0x141413 as Number;
    const G_DETRAINING    = 0x101214 as Number;
    const G_RECOVERY      = 0x0F1414 as Number;
    const G_MAINTAINING   = 0x14120F as Number;
    const G_PRODUCTIVE    = 0x141413 as Number;
    const G_PEAKING       = 0x17130C as Number;
    const G_UNPRODUCTIVE  = 0x121014 as Number;
    const G_STRAINED      = 0x171111 as Number;
    const G_OVERREACH     = 0x171310 as Number;

    // Treatment neutrals. Text stays neutral so the accent is the only
    // thing carrying colour meaning.
    const CREAM      = 0xF0EEE6 as Number;
    const INK        = 0x1A1915 as Number;
    const MUTED      = 0x6B675C as Number;
    const FAINT      = 0x8A867B as Number;
    const HAIRLINE   = 0xDCD6C6 as Number;
    const TRACK      = 0xC9C2AE as Number;

    // The cream carries the status too, but only in brightness - never
    // in hue, or the neutral half of the face would start competing with
    // the accent. A recovery day is meant to feel like a lamp turned
    // down; a peak week like one turned up.
    const CREAM_LIT  = 0xF7F5EE as Number;
    const CREAM_DIM  = 0xD9D6CD as Number;
    const CREAM_TEXT = 0xF0EEE6 as Number;
    const MUTED_D    = 0x8F8A7E as Number;
    const FAINT_D    = 0x6E6A61 as Number;
    const HAIRLINE_D = 0x33322E as Number;
    const TRACK_D    = 0x4E4B43 as Number;

    // ------------------------------------------------------------------
    // The dial ramp.
    //
    // Four stops per status, plus a cap on how far the overshoot pass is
    // allowed to lift. These are not a second accent: the dial is the one
    // element that climbs through a range, and a single flat colour on it
    // cannot say how far along the climb you are.
    //
    // Three rules are encoded here and should not be nudged by eye:
    //
    //   DEEP -> MID -> PALE rotates HUE as it climbs rather than merely
    //   brightening. Greens run blue-green to yellow-green, warms run
    //   amber to cream. An earlier set varied value alone and read as one
    //   flat colour at these luminances.
    //
    //   No stop is a mix toward the track. Mixing toward the warm rail
    //   turned the teals and blues into olive sludge, so each DEEP is a
    //   deeper version of its own hue.
    //
    //   MILK is the same hue with chroma drained and value raised -
    //   except OVERREACHING, whose MILK is warmer and MORE saturated than
    //   its PALE. That is the one deliberate asymmetry in the table:
    //   beating a goal on a strained day should read as heat, not reward.
    //
    // No-status is CLAY, and at full chroma rather than washed out. It is
    // the state the watch sits in until it has training history, so it is
    // the one most people see most of the time.
    //
    // It was a pale dusty version first and looked dirty on the wrist. A
    // desaturated orange turns brown and reads as grime; desaturated
    // greens and blues stay clean, which is why the other eight ramps
    // survive the same treatment and this one did not. Luminance is
    // unchanged from that version - only the chroma moved.
    const R_NONE         = [0xA34A22, 0xF59B70, 0xF9C0A3, 0xF6E6D8] as Array<Number>;
    const R_DETRAINING   = [0x4E5257, 0xB4B4AF, 0xD6D6D0, 0xEDEDE8] as Array<Number>;
    const R_RECOVERY     = [0x2F6B63, 0xA6D0C6, 0xCFE9E0, 0xEDF8F4] as Array<Number>;
    const R_MAINTAINING  = [0x3D5D7A, 0xA6B8CB, 0xD0DEEB, 0xEDF3F9] as Array<Number>;
    const R_PRODUCTIVE   = [0x3F7059, 0xA3CCA5, 0xCFE7C6, 0xEDF7E7] as Array<Number>;
    const R_PEAKING      = [0x8A5A28, 0xE0C48D, 0xF5E3B4, 0xFBF3DE] as Array<Number>;
    const R_UNPRODUCTIVE = [0x7A6434, 0xCBBA8F, 0xE4DBBC, 0xF4EFE0] as Array<Number>;
    const R_STRAINED     = [0x6E3F63, 0xC79FBE, 0xE3C8DC, 0xF4E6F0] as Array<Number>;
    const R_OVERREACHING = [0x8A4038, 0xD9A19A, 0xEFC4B6, 0xF5CDB4] as Array<Number>;

    // The dial's own rail, deliberately not TRACK_D (0x4E4B43). Against a
    // pale gradient the existing rail stops reading as unlit remainder
    // and starts reading as a second competing arc.
    const TRACK_DIAL     = 0x38372F as Number;

    // [DEEP, MID, PALE, MILK].
    function ramp(status as Number) as Array<Number> {
        if (status == STATUS_PEAKING)      { return R_PEAKING; }
        if (status == STATUS_PRODUCTIVE)   { return R_PRODUCTIVE; }
        if (status == STATUS_MAINTAINING)  { return R_MAINTAINING; }
        if (status == STATUS_RECOVERY)     { return R_RECOVERY; }
        if (status == STATUS_UNPRODUCTIVE) { return R_UNPRODUCTIVE; }
        if (status == STATUS_OVERREACHING) { return R_OVERREACHING; }
        if (status == STATUS_STRAINED)     { return R_STRAINED; }
        if (status == STATUS_DETRAINING)   { return R_DETRAINING; }
        return R_NONE;
    }

    // How much lift the overshoot pass has earned. Recovery is lowest by
    // design - a recovery day that beats its step goal is not a triumph.
    function rampCap(status as Number) as Float {
        if (status == STATUS_PEAKING)      { return 1.00; }
        if (status == STATUS_PRODUCTIVE)   { return 0.85; }
        if (status == STATUS_MAINTAINING)  { return 0.55; }
        if (status == STATUS_RECOVERY)     { return 0.50; }
        if (status == STATUS_UNPRODUCTIVE) { return 0.65; }
        if (status == STATUS_OVERREACHING) { return 0.75; }
        if (status == STATUS_STRAINED)     { return 0.60; }
        if (status == STATUS_DETRAINING)   { return 0.55; }
        return 0.70;
    }

    function accent(dark as Boolean, status as Number) as Number {
        if (dark) {
            if (status == STATUS_PEAKING)      { return A_PEAKING_D; }
            if (status == STATUS_PRODUCTIVE)   { return A_PRODUCTIVE_D; }
            if (status == STATUS_MAINTAINING)  { return A_MAINTAINING_D; }
            if (status == STATUS_RECOVERY)     { return A_RECOVERY_D; }
            if (status == STATUS_UNPRODUCTIVE) { return A_UNPRODUCTIVE_D; }
            if (status == STATUS_STRAINED)     { return A_STRAINED_D; }
            if (status == STATUS_OVERREACHING) { return A_OVERREACH_D; }
            if (status == STATUS_DETRAINING)   { return A_DETRAINING_D; }
            return A_NONE_D;
        }
        if (status == STATUS_PEAKING)      { return A_PEAKING_L; }
        if (status == STATUS_PRODUCTIVE)   { return A_PRODUCTIVE_L; }
        if (status == STATUS_MAINTAINING)  { return A_MAINTAINING_L; }
        if (status == STATUS_RECOVERY)     { return A_RECOVERY_L; }
        if (status == STATUS_UNPRODUCTIVE) { return A_UNPRODUCTIVE_L; }
        if (status == STATUS_STRAINED)     { return A_STRAINED_L; }
        if (status == STATUS_OVERREACHING) { return A_OVERREACH_L; }
        if (status == STATUS_DETRAINING)   { return A_DETRAINING_L; }
        return A_NONE_L;
    }

    function bg(dark as Boolean, status as Number) as Number {
        if (!dark) { return CREAM; }
        if (status == STATUS_PEAKING)      { return G_PEAKING; }
        if (status == STATUS_PRODUCTIVE)   { return G_PRODUCTIVE; }
        if (status == STATUS_MAINTAINING)  { return G_MAINTAINING; }
        if (status == STATUS_RECOVERY)     { return G_RECOVERY; }
        if (status == STATUS_UNPRODUCTIVE) { return G_UNPRODUCTIVE; }
        if (status == STATUS_STRAINED)     { return G_STRAINED; }
        if (status == STATUS_OVERREACHING) { return G_OVERREACH; }
        if (status == STATUS_DETRAINING)   { return G_DETRAINING; }
        return G_NONE;
    }

    function fg(dark as Boolean) as Number {
        return dark ? CREAM_TEXT : INK;
    }

    // The same neutral, moved a step up or down with the training. Only
    // the dark treatment takes it: on cream, ink has nowhere to go that
    // does not just look like a weaker print.
    function fgFor(dark as Boolean, status as Number) as Number {
        if (!dark) { return INK; }
        if (status == STATUS_PEAKING)    { return CREAM_LIT; }
        if (status == STATUS_RECOVERY)   { return CREAM_DIM; }
        if (status == STATUS_DETRAINING) { return CREAM_DIM; }
        return CREAM_TEXT;
    }

    function rule(dark as Boolean) as Number {
        return dark ? HAIRLINE_D : HAIRLINE;
    }

    function track(dark as Boolean) as Number {
        return dark ? TRACK_D : TRACK;
    }

    function secondary(dark as Boolean) as Number {
        return dark ? MUTED_D : MUTED;
    }

    function tertiary(dark as Boolean) as Number {
        return dark ? FAINT_D : FAINT;
    }

    // The complication hands back a localised string, so the label that
    // gets drawn is whatever the watch said. Only the theme lookup keys
    // off English, and anything unrecognised falls through to the neutral
    // palette rather than guessing.
    function statusFrom(label as String or Null) as Number {
        if (label == null) { return STATUS_NONE; }

        var s = label.toLower();
        if (s.find("peak") != null)        { return STATUS_PEAKING; }
        if (s.find("unproductive") != null){ return STATUS_UNPRODUCTIVE; }
        if (s.find("productive") != null)  { return STATUS_PRODUCTIVE; }
        if (s.find("maintain") != null)    { return STATUS_MAINTAINING; }
        if (s.find("recovery") != null)    { return STATUS_RECOVERY; }
        if (s.find("overreach") != null)   { return STATUS_OVERREACHING; }
        if (s.find("strain") != null)      { return STATUS_STRAINED; }
        if (s.find("detrain") != null)     { return STATUS_DETRAINING; }
        return STATUS_NONE;
    }
}
