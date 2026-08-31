import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class FaceView extends WatchUi.WatchFace {

    hidden var metrics as Metrics;
    hidden var renderer as Renderer or Null = null;

    hidden var reveal as Float = 1.0;
    hidden var revealStart as Number = 0;
    hidden var animator as Timer.Timer or Null = null;
    hidden var lowPower as Boolean = false;
    hidden var burnInProtected as Boolean = false;

    // Layout is stored as an index, not a name: a `list` setting is
    // only valid over a numeric property. Order matches settings.xml.
    hidden const LAYOUT_RADIAL = 0;
    hidden const LAYOUT_MERIDIAN = 1;
    hidden const LAYOUT_COLUMN = 2;
    hidden const LAYOUT_RINGS = 3;

    // ~250ms. Seen roughly a hundred times a day, so it has to read
    // as a settle, not a wait. Only the arcs move; the time is there
    // the instant the screen lights.
    //
    // Driven off the clock rather than off a tick count. The minimum
    // timer interval is a property of the host, not a constant, and
    // this device clamps above what the animation originally asked
    // for — counting ticks stretched the reveal to whatever the clamp
    // happened to be. Reading elapsed time instead means a slow device
    // drops frames rather than dragging the animation out.
    hidden const REVEAL_MS = 250;
    hidden const TICK_MS = 50;

    function initialize() {
        WatchFace.initialize();
        metrics = new Metrics();
    }

    function onLayout(dc as Dc) as Void {
        var settings = System.getDeviceSettings();
        if (settings has :requiresBurnInProtection) {
            burnInProtected = settings.requiresBurnInProtection;
        }
        buildRenderer();
    }

    // Rebuilt on settings change so switching layout or treatment
    // takes effect without a reinstall.
    function buildRenderer() as Void {
        // Both fall back to what properties.xml declares, NOT to the
        // zero value of their type.
        //
        // `dark` defaulted to false and shipped a cream watch face: on a
        // sideloaded build the device returned null for the property and
        // the face took the light treatment, which is the opposite of
        // what it is designed for. The simulator hid it because it had a
        // stored value. getValue is also wrapped, because a property the
        // store has never seen can throw rather than answer null.
        var dark = true;
        var layout = LAYOUT_RADIAL;

        try {
            var storedDark = Properties.getValue("darkTreatment");
            if (storedDark != null) { dark = storedDark as Boolean; }
        } catch (ex) {
            dark = true;
        }

        try {
            var storedLayout = Properties.getValue("layout");
            if (storedLayout != null) { layout = storedLayout as Number; }
        } catch (ex) {
            layout = LAYOUT_RADIAL;
        }

        if (layout == LAYOUT_MERIDIAN) {
            renderer = new MeridianRenderer(dark);
        } else if (layout == LAYOUT_COLUMN) {
            renderer = new ColumnRenderer(dark);
        } else if (layout == LAYOUT_RINGS) {
            renderer = new ArcsRenderer(dark);
        } else {
            renderer = new RadialRenderer(dark);
        }
    }

    function onUpdate(dc as Dc) as Void {
        metrics.refresh();

        if (renderer == null) { buildRenderer(); }

        // On AMOLED, low power means always-on display: strict pixel
        // budget, burn-in risk, and no seconds. Hand off to the
        // stripped ambient state rather than dimming the full face.
        if (lowPower && burnInProtected) {
            (renderer as Renderer).drawAmbient(dc, metrics);
            return;
        }

        (renderer as Renderer).draw(dc, metrics, reveal);
    }

    // Only fires on always-active MIP devices. AMOLED always-on never
    // gets here, which is why nothing on this face depends on seconds.
    function onPartialUpdate(dc as Dc) as Void {
        if (renderer == null) { return; }
        (renderer as Renderer).drawPartial(dc, metrics);
    }

    function onExitSleep() as Void {
        lowPower = false;
        startReveal();
    }

    function onEnterSleep() as Void {
        lowPower = true;
        stopReveal();
        reveal = 1.0;
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        stopReveal();
        FaceFonts.release();
    }

    hidden function startReveal() as Void {
        stopReveal();

        reveal = 0.0;
        revealStart = System.getTimer();
        animator = new Timer.Timer();
        (animator as Timer.Timer).start(method(:onRevealTick), TICK_MS, true);
    }

    hidden function stopReveal() as Void {
        if (animator != null) {
            (animator as Timer.Timer).stop();
            animator = null;
        }
    }

    function onRevealTick() as Void {
        // Timers are unavailable in low power. Bail rather than
        // burn the power budget if a tick lands after sleep.
        if (lowPower) {
            stopReveal();
            return;
        }

        var elapsed = System.getTimer() - revealStart;
        reveal = elapsed.toFloat() / REVEAL_MS;
        if (reveal >= 1.0) {
            reveal = 1.0;
            stopReveal();
        }
        WatchUi.requestUpdate();
    }
}
