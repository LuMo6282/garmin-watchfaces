import Toybox.Activity;
import Toybox.Application.Properties;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// One snapshot of everything the face draws.
// Every field is nullable. The face must handle null by omitting the
// element, never by drawing a placeholder or leaving a hole.
//
// Carried over from Clay and cut down to what Recon actually reads.
// Clay's Metrics serves four layouts between them wanting calories,
// notifications, phone state, watch battery, the recovery clock and a
// cloudiness bucket for the sky dial. Recon draws none of that, and a
// reader that runs on every frame to fill a field nobody paints is
// bytecode and battery spent on nothing.
class Metrics {

    var hour as Number = 0;
    var minute as Number = 0;
    // Weekday, day, month. The extra word is what stops a bare weekday
    // and number reading as a fragment.
    var dateLineLong as String = "";

    // Seconds since local midnight. The sun times arrive in the same
    // units.
    hidden var secondsToday as Number = 0;

    var steps as Number or Null = null;
    var stepGoal as Number or Null = null;
    var heartRate as Number or Null = null;
    var bodyBattery as Number or Null = null;

    // The localised label the watch reports, and the theme it maps to.
    var trainingLabel as String or Null = null;
    var trainingStatus as Number = Theme.STATUS_NONE;

    // Whichever of sunrise / sunset comes next, as seconds since
    // midnight, plus which of the two it is.
    var sunAt as Number or Null = null;
    var sunIsRise as Boolean = true;

    // Both of today's sun times, kept whole. The next event alone is
    // enough to print a line, but not to draw the day as a span.
    var sunriseAt as Number or Null = null;
    var sunsetAt as Number or Null = null;

    var temperature as Number or Null = null;

    function refresh() as Void {
        var now = System.getClockTime();
        hour = now.hour;
        minute = now.min;
        secondsToday = (now.hour * 3600) + (now.min * 60) + now.sec;

        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        dateLineLong = Lang.format("$1$ $2$ $3$",
            [today.day_of_week, today.day, today.month]);

        // Each reader is isolated. They were called bare, so anything
        // that threw — a permission the device declines, an API a
        // firmware build does not answer — took out every reader AFTER
        // it as well, and the face lost heart rate, body battery,
        // weather and the complications all at once with no clue which
        // one had actually failed.
        try { readActivity(); }       catch (ex) {}
        try { readHeartRate(); }      catch (ex) {}
        try { readBodyBattery(); }    catch (ex) {}
        try { readWeather(); }        catch (ex) {}
        try { readComplications(); }  catch (ex) {}
    }

    hidden function readActivity() as Void {
        var info = ActivityMonitor.getInfo();
        if (info == null) { return; }

        if (info has :steps) { steps = info.steps; }
        if (info has :stepGoal) { stepGoal = info.stepGoal; }
    }

    hidden function readHeartRate() as Void {
        // Live sample first — it is the freshest during an activity.
        var activity = Activity.getActivityInfo();
        if (activity != null && activity.currentHeartRate != null) {
            heartRate = activity.currentHeartRate;
            return;
        }

        // Fall back to the most recent logged sample.
        if (ActivityMonitor has :getHeartRateHistory) {
            var iterator = ActivityMonitor.getHeartRateHistory(null, true);
            if (iterator != null) {
                // Walk deep. On the watch the newest entries in the
                // window are routinely empty or INVALID_HR_SAMPLE — the
                // iterator comes back fine and the first several samples
                // carry nothing, which is why a short walk reported "no
                // heart rate" on a watch that plainly had one.
                for (var i = 0; i < 240; i += 1) {
                    var sample = iterator.next();
                    if (sample == null) { return; }
                    if (sample.heartRate != null
                        && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        heartRate = sample.heartRate;
                        return;
                    }
                }
            }
        }
    }

    hidden function readBodyBattery() as Void {
        // Not present on every device. No capability check, no face.
        if (!(Toybox has :SensorHistory)) { return; }
        if (!(Toybox.SensorHistory has :getBodyBatteryHistory)) { return; }

        // `:period => 1` asks for exactly ONE sample. If that sample
        // happens to be empty — which it often is — the iterator comes
        // back valid and yields nothing, and no amount of walking helps
        // because there is only ever one entry in it. Ask for a window
        // instead and take the newest entry that carries a reading.
        var iterator = Toybox.SensorHistory.getBodyBatteryHistory({
            :period => new Time.Duration(6 * 60 * 60),
            :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST
        });
        if (iterator == null) { return; }

        // Walk forward until a sample actually carries a reading. The
        // newest entry in the window can be an empty slot, and taking
        // only next() then reported "no body battery" on a watch that
        // had a perfectly good one a minute earlier.
        for (var i = 0; i < 240; i += 1) {
            var sample = iterator.next();
            if (sample == null) { return; }
            if (sample.data != null) {
                bodyBattery = sample.data.toNumber();
                return;
            }
        }
    }

    hidden function readWeather() as Void {
        // Cached from the last phone sync, so it is often stale and
        // sometimes null. Treated as optional decoration, never load-bearing.
        if (!(Toybox has :Weather)) { return; }

        var conditions = Toybox.Weather.getCurrentConditions();
        if (conditions == null || conditions.temperature == null) { return; }

        // Fahrenheit regardless of the system unit setting, by request.
        temperature = ((conditions.temperature * 9.0 / 5.0) + 32).toNumber();
    }

    // Training status and the sun times all arrive as native
    // complications. Reading one that a device does not populate throws
    // rather than returning null, so each is asked for separately and
    // any failure just leaves that element off the face.
    hidden function readComplications() as Void {
        if (!(Toybox has :Complications)) { return; }

        trainingLabel = statusLabel();
        trainingStatus = Theme.statusFrom(trainingLabel);
        applyDemoStatus();
        applyDemoSteps();

        var rise = complicationNumber(Complications.COMPLICATION_TYPE_SUNRISE);
        var set = complicationNumber(Complications.COMPLICATION_TYPE_SUNSET);
        sunriseAt = rise;
        sunsetAt = set;

        // Whichever comes next. After sunset the answer is tomorrow's
        // sunrise, which is the same clock time to a good enough
        // approximation for a watch face.
        if (rise != null && secondsToday < rise) {
            sunAt = rise;
            sunIsRise = true;
        } else if (set != null && secondsToday < set) {
            sunAt = set;
            sunIsRise = false;
        } else if (rise != null) {
            sunAt = rise;
            sunIsRise = true;
        }
    }

    // The simulator has no training status to give — its complication
    // answers "no result" forever — so there is no way to see the one
    // element that drives the whole palette without a switch for it.
    //
    // Off by default, and it must stay off: a sideloaded build gets no
    // settings UI on the watch, so whatever ships here is permanent.
    // Set it in properties.xml and rebuild to preview a state, then put
    // it back to 0. It overrides the label as well as the colour, so
    // what is previewed is the real thing rather than a tinted face.
    hidden function applyDemoStatus() as Void {
        // Guarded: a property the device's store has never seen can throw
        // rather than answer null, and this runs inside refresh() on every
        // single frame. An unguarded read here takes the whole face down.
        var demo = null;
        try {
            demo = Properties.getValue("demoStatus");
        } catch (ex) {
            return;
        }
        if (demo == null) { return; }

        var n = demo as Number;
        if (n <= 0 || n > 8) { return; }

        trainingStatus = n;
        trainingLabel = demoLabels[n - 1];
    }

    // The step goal the demo override counts against when the watch has
    // not supplied one. Only ever reached in the simulator.
    hidden const DEMO_GOAL = 8000;

    // Percent of goal, so 140 puts the dial 40% into its second pass.
    // Ships at 0 like every other demo switch: a sideloaded build has no
    // settings UI on the watch to turn it back off.
    hidden function applyDemoSteps() as Void {
        var demo = null;
        try {
            demo = Properties.getValue("demoSteps");
        } catch (ex) {
            return;
        }
        if (demo == null) { return; }

        var pct = demo as Number;
        if (pct <= 0) { return; }

        if (stepGoal == null || (stepGoal as Number) <= 0) { stepGoal = DEMO_GOAL; }
        steps = ((stepGoal as Number) * pct) / 100;
    }

    hidden const demoLabels as Array<String> = [
        "detraining", "recovery", "maintaining",
        "productive", "peaking", "unproductive", "strained",
        "overreaching"
    ];

    // The training status complication answers even when it has nothing
    // to say, and what it hands back is a sentence rather than a status:
    // the simulator returns "no result", devices return their own
    // equivalent before enough history has accrued. Printed as-is it
    // reads as a training state the wearer has never heard of, so the
    // known placeholders are treated as absence.
    //
    // Anything else is kept, including a label this build cannot theme.
    // An unrecognised word still names the wearer's status truthfully —
    // it only costs the accent, which falls through to neutral — and
    // dropping it would blank the line on every non-English watch.
    hidden function statusLabel() as String or Null {
        var raw = complicationString(Complications.COMPLICATION_TYPE_TRAINING_STATUS);
        if (raw == null) { return null; }

        var s = raw as String;
        if (s.equals("")
            || s.equals("no result")
            || s.equals("none")
            || s.equals("--")) {
            return null;
        }
        return s;
    }

    hidden function complicationNumber(type as Complications.Type) as Number or Null {
        try {
            var c = Complications.getComplication(new Complications.Id(type));
            if (c != null && c.value != null) { return c.value as Number; }
        } catch (ex) {
            return null;
        }
        return null;
    }

    hidden function complicationString(type as Complications.Type) as String or Null {
        try {
            var c = Complications.getComplication(new Complications.Id(type));
            if (c != null && c.value != null) { return (c.value as String).toLower(); }
        } catch (ex) {
            return null;
        }
        return null;
    }

    // 0.0 to 2.0, or null when there is nothing meaningful to show.
    //
    // Deliberately NOT clamped at 1.0. The scale's second pass is a
    // picture of the overshoot, so everything above the goal is the
    // interesting half; clamping here is the one edit that would leave
    // the feature looking implemented and doing nothing. 2.0 is the far
    // end because the scale holds its state past double rather than
    // starting a third pass.
    function stepProgress() as Float or Null {
        if (steps == null || stepGoal == null || stepGoal <= 0) { return null; }
        var ratio = steps.toFloat() / stepGoal.toFloat();
        return ratio > 2.0 ? 2.0 : ratio;
    }

    // Steps at a width that fits a column: thousands to one decimal once
    // there are any, plain below that. A five-figure step count would
    // set wider than the value beside it and break the row's rhythm.
    function stepsShort() as String or Null {
        if (steps == null) { return null; }

        var n = steps as Number;
        if (n < 1000) { return n.format("%d"); }
        return (n / 1000.0).format("%.1f") + "K";
    }

    // Always 24-hour and always zero-padded, whatever the wearer has
    // set for the system clock. Clay follows the device setting; this
    // face deliberately does not. 24-hour time is half of what makes a
    // readout read as a readout, and a clock that is four glyphs wide
    // in the morning and five in the afternoon cannot sit still inside
    // a reticle that does not move.
    function timeString() as String {
        return Lang.format("$1$:$2$",
            [hour.format("%02d"), minute.format("%02d")]);
    }

    // The next sun event as a clock time, on the same 24-hour clock as
    // everything else here.
    function sunString() as String or Null {
        if (sunAt == null) { return null; }

        var h = (sunAt / 3600).toNumber();
        var m = ((sunAt % 3600) / 60).toNumber();
        return Lang.format("$1$:$2$", [h.format("%02d"), m.format("%02d")]);
    }
}
