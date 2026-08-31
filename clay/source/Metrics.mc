import Toybox.Activity;
import Toybox.Application.Properties;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// One snapshot of everything a layout might want to draw.
// Every field is nullable. Layouts must handle null by omitting
// the element, never by drawing a placeholder or leaving a hole.
class Metrics {

    var hour as Number = 0;
    var minute as Number = 0;
    var dateLine as String = "";

    // The same date with the month on the end. Radial sets it as the
    // one line above the time, where the extra word is what stops a
    // bare weekday and number reading as a fragment; the editorial
    // layouts have the month elsewhere and keep using `dateLine`.
    var dateLineLong as String = "";

    // Seconds since local midnight, before the 12-hour clock rewrites
    // `hour`. The sun times arrive in the same units.
    hidden var secondsToday as Number = 0;
    hidden var is24Hour as Boolean = true;

    var steps as Number or Null = null;
    var stepGoal as Number or Null = null;
    var heartRate as Number or Null = null;
    var bodyBattery as Number or Null = null;
    var calories as Number or Null = null;

    // Hours left on the recovery clock, and whether the watch reports
    // one at all. The two are different facts: a null count on a device
    // that does report means recovered, and should read as such, while a
    // device that reports nothing should show no readiness arc.
    var recoveryHours as Number or Null = null;
    var hasRecovery as Boolean = false;

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

    var watchBattery as Number or Null = null;
    var temperature as Number or Null = null;

    // 0.0 clear to 1.0 overcast. Garmin publishes no cloud percentage -
    // only a condition enum - so this is bucketed from that. Null means
    // no weather at all, which the sky dial treats as clear rather than
    // as overcast: a watch with no phone nearby should not paint a
    // permanently grey sky.
    var cloudiness as Float or Null = null;
    var notifications as Number = 0;
    var phoneConnected as Boolean = false;

    function refresh() as Void {
        var now = System.getClockTime();
        hour = now.hour;
        minute = now.min;
        secondsToday = (now.hour * 3600) + (now.min * 60) + now.sec;

        var settings = System.getDeviceSettings();
        is24Hour = settings.is24Hour;
        if (!is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }

        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        dateLine = Lang.format("$1$ $2$", [today.day_of_week, today.day]).toLower();
        dateLineLong = Lang.format("$1$ $2$ $3$",
            [today.day_of_week, today.day, today.month]).toLower();

        notifications = settings.notificationCount;
        phoneConnected = settings.phoneConnected;

        var stats = System.getSystemStats();
        watchBattery = stats.battery.toNumber();

        // Each reader is isolated. They were called bare, so anything
        // that threw - a permission the device declines, an API a
        // firmware build does not answer - took out every reader AFTER
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
        if (info has :calories) { calories = info.calories; }

        // Garmin computes Training Readiness on the watch but never
        // publishes it to Connect IQ. Time to recovery is the nearest
        // thing the platform hands over and it answers the same
        // question: whether there is a hard session in you today. It is
        // documented in hours, so there is no unit to guess at.
        if (info has :timeToRecovery) {
            hasRecovery = true;
            recoveryHours = null;
            if (info.timeToRecovery != null) {
                var hours = info.timeToRecovery as Number;
                if (hours > 0) { recoveryHours = hours; }
            }
        }
    }

    hidden function readHeartRate() as Void {
        // Live sample first - it is the freshest during an activity.
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
                // window are routinely empty or INVALID_HR_SAMPLE - the
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
        // happens to be empty - which it often is - the iterator comes
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

        if (conditions.condition != null) {
            cloudiness = cloudFrom(conditions.condition as Number);
        }
    }

    // The sky dial only needs to know how much of the sky is covered, so
    // the fifty-odd conditions collapse to five buckets. Anything
    // precipitating or visibility-limiting counts as fully covered -
    // what matters is that the blue is gone, not what is falling.
    hidden function cloudFrom(c as Number) as Float {
        var w = Toybox.Weather;

        if (c == w.CONDITION_CLEAR || c == w.CONDITION_FAIR) { return 0.0; }

        if (c == w.CONDITION_MOSTLY_CLEAR || c == w.CONDITION_PARTLY_CLEAR
            || c == w.CONDITION_THIN_CLOUDS) { return 0.25; }

        if (c == w.CONDITION_PARTLY_CLOUDY
            || c == w.CONDITION_SCATTERED_SHOWERS
            || c == w.CONDITION_SCATTERED_THUNDERSTORMS
            || c == w.CONDITION_CHANCE_OF_SHOWERS
            || c == w.CONDITION_CHANCE_OF_RAIN_SNOW
            || c == w.CONDITION_CHANCE_OF_SNOW
            || c == w.CONDITION_CHANCE_OF_THUNDERSTORMS) { return 0.5; }

        if (c == w.CONDITION_MOSTLY_CLOUDY || c == w.CONDITION_CLOUDY
            || c == w.CONDITION_HAZE || c == w.CONDITION_HAZY
            || c == w.CONDITION_MIST || c == w.CONDITION_SMOKE
            || c == w.CONDITION_DUST || c == w.CONDITION_SAND) { return 0.75; }

        if (c == w.CONDITION_UNKNOWN) { return 0.0; }

        // Everything left is rain, snow, fog or a storm.
        return 1.0;
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

    // The simulator has no training status to give - its complication
    // answers "no result" forever - so there is no way to see the one
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
    // An unrecognised word still names the wearer's status truthfully -
    // it only costs the accent, which falls through to neutral - and
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
    // Deliberately NOT clamped at 1.0. The dial's second pass is a
    // picture of the overshoot, so everything above the goal is the
    // interesting half; clamping here is the one edit that would leave
    // the feature looking implemented and doing nothing. 2.0 is the far
    // end because the dial holds its state past double rather than
    // starting a third pass.
    function stepProgress() as Float or Null {
        if (steps == null || stepGoal == null || stepGoal <= 0) { return null; }
        var ratio = steps.toFloat() / stepGoal.toFloat();
        return ratio > 2.0 ? 2.0 : ratio;
    }

    function bodyProgress() as Float or Null {
        if (bodyBattery == null) { return null; }
        return bodyBattery.toFloat() / 100.0;
    }

    // The recovery clock is open-ended in principle, so the arc needs a
    // scale to draw against. 72 hours is the far end of what the watch
    // reports after a hard session; past that the arc simply reads empty.
    hidden const RECOVERY_SCALE = 72.0;

    // True when the watch knows both ends of today's daylight, which is
    // what the day arc is a picture of.
    function hasDaylight() as Boolean {
        return sunriseAt != null && sunsetAt != null && (sunsetAt as Number) > (sunriseAt as Number);
    }

    // How far through the daylight the day has got, 0.0 to 1.0, or null
    // outside it. Null is not zero: before dawn and after dusk the sun
    // is not on the arc at all, and the layout omits it rather than
    // parking it at an end.
    function dayProgress() as Float or Null {
        if (!hasDaylight()) { return null; }

        var rise = sunriseAt as Number;
        var set = sunsetAt as Number;
        if (secondsToday < rise || secondsToday > set) { return null; }

        return (secondsToday - rise).toFloat() / (set - rise).toFloat();
    }

    // Progress through whichever span the watch is currently in, day or
    // night, toward the sun event that ends it. Not the same as
    // `dayProgress`: that one is null after dusk because the sun is not
    // on the day arc any more, whereas this keeps running through the
    // night toward sunrise, which is what the bottom dial counts down.
    function sunProgress() as Float or Null {
        if (sunriseAt == null || sunsetAt == null) { return null; }

        var rise = sunriseAt as Number;
        var set = sunsetAt as Number;
        if (set <= rise) { return null; }

        if (secondsToday >= rise && secondsToday < set) {
            return (secondsToday - rise).toFloat() / (set - rise).toFloat();
        }

        // Night, wrapping midnight: sunset through to tomorrow's sunrise.
        // Tomorrow's rise is treated as today's, which is minutes out at
        // worst and invisible on a dial this size.
        var span = (86400 - set) + rise;
        if (span <= 0) { return null; }

        var into = secondsToday >= set ? (secondsToday - set) : (86400 - set + secondsToday);
        return into.toFloat() / span.toFloat();
    }

    // Steps at a width that fits a column: thousands to one decimal once
    // there are any, plain below that. A five-figure step count would
    // set wider than the value beside it and break the row's rhythm.
    function stepsShort() as String or Null {
        if (steps == null) { return null; }

        var n = steps as Number;
        if (n < 1000) { return n.format("%d"); }
        return (n / 1000.0).format("%.1f") + "k";
    }

    // Readiness, as the inverse of the recovery clock: full when there
    // is no recovery left to serve, short when a hard session is still
    // being paid off. Null only on a device that reports nothing, so the
    // layout drops the arc rather than drawing a full one it cannot back.
    function readiness() as Float or Null {
        if (!hasRecovery) { return null; }
        if (recoveryHours == null) { return 1.0; }

        var ratio = (recoveryHours as Number).toFloat() / RECOVERY_SCALE;
        if (ratio > 1.0) { ratio = 1.0; }
        return 1.0 - ratio;
    }

    // What the readiness arc is showing, in as few characters as it can
    // be said: the hours left, or the fact that there are none.
    function recoveryLabel() as String {
        if (recoveryHours == null) { return "ready"; }
        return (recoveryHours as Number).format("%d") + "h";
    }

    function timeString() as String {
        return Lang.format("$1$:$2$", [hour, minute.format("%02d")]);
    }

    // The next sun event as a clock time, in the same 12/24 hour mode
    // the wearer has set for the face itself.
    function sunString() as String or Null {
        if (sunAt == null) { return null; }

        var h = (sunAt / 3600).toNumber();
        var m = ((sunAt % 3600) / 60).toNumber();
        if (!is24Hour) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return Lang.format("$1$:$2$", [h, m.format("%02d")]);
    }
}
