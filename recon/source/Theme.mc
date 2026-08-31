import Toybox.Graphics;
import Toybox.Lang;

// Recon's palette. Olive-drab structure, bone readouts, one signal
// colour, and nothing else.
//
// Clay carries nine warm accent ramps, one per training status, and
// blends between four stops to say how far along a climb you are. None
// of that survives here, and the deletion is the design: an instrument
// panel does not have moods. It has graduations, which are structure and
// never change, and it has a signal, which is information and has very
// few states.
//
// So the nine statuses collapse onto THREE signals, which is how a real
// status board reads:
//
//   NOMINAL   amber   the system is doing its job
//   STANDBY   steel   the system is deliberately idling
//   WARNING   red     the system is past a limit
//
// Each signal is paired with its own family of STRUCTURE, chosen to
// oppose the signal's temperature. See the structure block below.
//
// That loses the ability to tell peaking from productive by colour. It
// is meant to: the status WORD is set right under the time and says
// which one it is. Colour is reserved for the thing you need to read
// without reading — whether anything is wrong — and nine colours cannot
// answer that question at a glance while three can.
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

    // Near-black. On this AMOLED panel the ground is mostly unlit pixels
    // whatever it is, so these differ only in the last few percent.
    //
    // Three grounds, each carrying a few percent of its own structure
    // family rather than of the signal. At these luminances the tint is
    // nearly invisible on its own; what it does is stop the graduations
    // looking tinted by sitting them on something related to them.
    const GROUND     = 0x070806 as Number;   // nominal, green cast
    const GROUND_SND = 0x080706 as Number;   // standby, warm cast
    const GROUND_GUN = 0x06080A as Number;   // warning, cool cast

    // The readouts. Warm off-white, not pure white — pure white on this
    // ground reads as a screen rather than as a printed panel.
    const BONE       = 0xE8E5D7 as Number;
    const BONE_DIM   = 0xA8A697 as Number;

    // ------------------------------------------------------------------
    // STRUCTURE — the graduations, the rules, the labels, the reticle.
    // Three levels, and now three FAMILIES, one paired to each signal.
    //
    // One olive served all three at first and it does not work. Olive
    // against red is the bad case: both are muddy mid-chroma colours a
    // short way apart on the wheel, so a warning day came out looking
    // dirty rather than urgent — which is the one state that has to read
    // cleanly. Olive against amber is fine, which is why it survives as
    // the nominal family.
    //
    // The rule the three families follow: STRUCTURE OPPOSES THE SIGNAL'S
    // TEMPERATURE. A warm signal gets cool structure, a cool signal gets
    // warm structure. That buys two things at once — the pairing
    // harmonises instead of clashing, and the structure can never be
    // mistaken for the signal, which is the failure the pale-olive
    // STANDBY already walked into once.
    //
    // There are three families and not nine on purpose. Nine statuses
    // already collapse to three signals; giving STRAINED and
    // OVERREACHING different structure would make two states that show
    // the same red look like different states for no reason, and would
    // reintroduce exactly the nine-way palette this face deleted.

    // NOMINAL — olive drab against the amber. Unchanged; it is the
    // face's identity and the most-seen state.
    const OD_LIT     = 0x94A06B as Number;   // labels, endstops, in-range majors
    const OD         = 0x5F6947 as Number;   // in-range minors, out-of-range majors
    const OD_DEEP    = 0x323829 as Number;   // out-of-range minors, the rule

    // STANDBY — warm sand against the cool steel.
    const SAND_LIT   = 0x9A8E70 as Number;
    const SAND       = 0x635B47 as Number;
    const SAND_DEEP  = 0x343026 as Number;

    // WARNING — cool gunmetal against the red. This is the pairing the
    // whole change exists for: red on grey-blue is a warning panel, red
    // on olive is a mess.
    const GUN_LIT    = 0x7E8A92 as Number;
    const GUN        = 0x4E575D as Number;
    const GUN_DEEP   = 0x2B3034 as Number;

    // The three signals, each with the dimmed version the finished first
    // lap drops back to.
    const AMBER      = 0xFFB000 as Number;
    const AMBER_DIM  = 0x6E4B00 as Number;

    // STANDBY is a cool STEEL, not a pale olive.
    //
    // It was 0x9FAA7C first, which is an olive one shade up from the
    // structure — and OD_LIT, the colour of the major graduations and
    // the labels, is 0x94A06B. Those are the same colour to the eye. In
    // the three standby states the lit run and the unlit remainder
    // became indistinguishable and the gauge stopped reading at all,
    // which is the one thing a signal colour may never do.
    //
    // A signal has to separate from the structure by HUE, not by a shade
    // of the structure's own hue. Steel also agrees with what Clay meant
    // by these states: it ran teal for recovery and cold steel for
    // detraining, both of them cool against its warm accents.
    const STANDBY    = 0x8FB6CE as Number;
    const STANDBY_DIM= 0x2F4655 as Number;

    const WARN       = 0xE33D24 as Number;
    const WARN_DIM   = 0x631A0F as Number;

    // Always-on. Dimmer than anything the awake face draws, and
    // deliberately not the signal colour — the ambient state is the
    // time and nothing else, so it should not appear to be reporting.
    const AMBIENT    = 0x87857A as Number;

    // Strained and overreaching, and nothing else. Asked by anything that
    // should ESCALATE rather than tint.
    function isWarning(status as Number) as Boolean {
        return status == STATUS_STRAINED || status == STATUS_OVERREACHING;
    }

    function isStandby(status as Number) as Boolean {
        return status == STATUS_RECOVERY
            || status == STATUS_DETRAINING
            || status == STATUS_UNPRODUCTIVE;
    }

    // ------------------------------------------------------------------
    // The structure family paired to the current signal. Every
    // structural colour on the face goes through these three, so a state
    // never mixes families.

    function structLit(status as Number) as Number {
        if (isWarning(status)) { return GUN_LIT; }
        if (isStandby(status)) { return SAND_LIT; }
        return OD_LIT;
    }

    function struct(status as Number) as Number {
        if (isWarning(status)) { return GUN; }
        if (isStandby(status)) { return SAND; }
        return OD;
    }

    function structDeep(status as Number) as Number {
        if (isWarning(status)) { return GUN_DEEP; }
        if (isStandby(status)) { return SAND_DEEP; }
        return OD_DEEP;
    }

    function ground(status as Number) as Number {
        if (isWarning(status)) { return GROUND_GUN; }
        if (isStandby(status)) { return GROUND_SND; }
        return GROUND;
    }

    // The reticle around the clock.
    //
    // Structure on every ordinary day — and the warning itself when there
    // is one. This is the single place the signal is allowed off the
    // gauge and the status word, and it is allowed there because the
    // reticle is STRUCTURE: it frames a value without being one, so it
    // cannot be misread as a claim about the time inside it.
    //
    // The same licence is deliberately NOT given to the row figures, the
    // time or the date. Those are values, and a value that changes colour
    // is saying something about itself — at which point red means both
    // "your training is past a limit" and "this number is past a limit",
    // and it stops answering either question.
    //
    // Only the warning escalates. Tinting the frame on all nine states
    // was the other candidate and it is worse: seven days out of nine it
    // would put a permanent wash over the middle of the face, spend the
    // OD character to say "nothing is happening", and leave the warning
    // with nowhere left to go.
    function frame(status as Number) as Number {
        return isWarning(status) ? WARN : struct(status);
    }

    // Which signal a training status raises.
    //
    // UNPRODUCTIVE sits in STANDBY rather than in WARNING. Unproductive
    // means the load is not paying off, which is a reason to change what
    // you are doing; strained and overreaching mean the body is past
    // what it can absorb, which is a reason to stop. Only the second
    // pair earns red, or red stops meaning anything.
    //
    // No-status is NOMINAL. It is the state the watch sits in until it
    // has training history — the first week, a rest block, any lapse —
    // and the most-seen state must not look like a fault.
    function signal(status as Number) as Number {
        if (isWarning(status)) {
            return WARN;
        }
        if (isStandby(status)) {
            return STANDBY;
        }
        return AMBER;
    }

    // The same signal, spent. The scale's completed first lap drops to
    // this so the second pass has contrast to climb against while the
    // lap it finished stays on the face as a record.
    function signalDim(status as Number) as Number {
        if (isWarning(status)) {
            return WARN_DIM;
        }
        if (isStandby(status)) {
            return STANDBY_DIM;
        }
        return AMBER_DIM;
    }

    // The complication hands back a localised string, so the label that
    // gets drawn is whatever the watch said. Only the lookup keys off
    // English, and anything unrecognised falls through to NOMINAL rather
    // than guessing — an unknown word must not raise a warning.
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
