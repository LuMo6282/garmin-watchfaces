import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Owns the lifecycle and the data. The face itself only knows how to
// put pixels down.
//
// Clay picks one of four renderers off a stored property. Recon has one
// face and no treatment switch, so there is no property to read here -
// which also sidesteps the trap that shipped Clay's first sideload as a
// cream watch face: a property the device store has never seen can
// throw or answer null, and a fallback that disagrees with
// properties.xml is invisible in the simulator.
class FaceView extends WatchUi.WatchFace {

    hidden var metrics as Metrics;
    hidden var face as BezelFace;

    hidden var reveal as Float = 1.0;
    hidden var revealStart as Number = 0;
    hidden var animator as Timer.Timer or Null = null;
    hidden var lowPower as Boolean = false;
    hidden var burnInProtected as Boolean = false;

    // ~250ms. Seen roughly a hundred times a day, so it has to read as a
    // settle, not a wait. Only the scale moves; the time is there the
    // instant the screen lights.
    //
    // Driven off the clock rather than off a tick count. The minimum
    // timer interval is a property of the host, not a constant, and this
    // device clamps above what the animation asks for - counting ticks
    // stretched the reveal to whatever the clamp happened to be.
    hidden const REVEAL_MS = 250;
    hidden const TICK_MS = 50;

    function initialize() {
        WatchFace.initialize();
        metrics = new Metrics();
        face = new BezelFace();
    }

    function onLayout(dc as Dc) as Void {
        var settings = System.getDeviceSettings();
        if (settings has :requiresBurnInProtection) {
            burnInProtected = settings.requiresBurnInProtection;
        }
    }

    function onUpdate(dc as Dc) as Void {
        metrics.refresh();

        // On AMOLED, low power means always-on display: strict pixel
        // budget, burn-in risk, and no seconds. Hand off to the stripped
        // ambient state rather than dimming the full face.
        if (lowPower && burnInProtected) {
            face.drawAmbient(dc, metrics);
            return;
        }

        face.draw(dc, metrics, reveal);
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
        // Timers are unavailable in low power. Bail rather than burn the
        // power budget if a tick lands after sleep.
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
