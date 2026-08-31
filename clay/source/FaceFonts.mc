import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Three sizes of one serif: the time, the figures in the stat row, and
// the words. Keeping labels on the same face as the numerals is most of
// what stops the face reading as data dropped onto a background.
//
// Rez symbols resolve at compile time, so `Rez.Fonts has :serifTime`
// cannot be asked at runtime — the symbol only exists once the resource
// does. The switch is a build annotation: drop `noSerifFont` from
// `base.excludeAnnotations` in monkey.jungle to fall back to the
// built-in faces on a device with no font generated for it.
module FaceFonts {

    var cachedTime as FontType or Null = null;
    var cachedSmall as FontType or Null = null;
    var cachedLabel as FontType or Null = null;
    var cachedMicro as FontType or Null = null;

    // Radial is set in a light sans rather than the serif. It is a
    // second family, not a replacement: the three editorial layouts are
    // built on the serif's colour and swapping it under them would
    // rebalance faces that are already right.
    var cachedSansTime as FontType or Null = null;
    var cachedSansSmall as FontType or Null = null;
    var cachedSansLabel as FontType or Null = null;
    var cachedSansMicro as FontType or Null = null;

    function time() as FontType {
        if (cachedTime == null) { cachedTime = loadTime(); }
        return cachedTime as FontType;
    }

    function small() as FontType {
        if (cachedSmall == null) { cachedSmall = loadSmall(); }
        return cachedSmall as FontType;
    }

    function label() as FontType {
        if (cachedLabel == null) { cachedLabel = loadLabel(); }
        return cachedLabel as FontType;
    }

    function micro() as FontType {
        if (cachedMicro == null) { cachedMicro = loadMicro(); }
        return cachedMicro as FontType;
    }

    function sansTime() as FontType {
        if (cachedSansTime == null) {
            cachedSansTime = WatchUi.loadResource(Rez.Fonts.sansTime) as FontType;
        }
        return cachedSansTime as FontType;
    }

    function sansSmall() as FontType {
        if (cachedSansSmall == null) {
            cachedSansSmall = WatchUi.loadResource(Rez.Fonts.sansSmall) as FontType;
        }
        return cachedSansSmall as FontType;
    }

    function sansLabel() as FontType {
        if (cachedSansLabel == null) {
            cachedSansLabel = WatchUi.loadResource(Rez.Fonts.sansLabel) as FontType;
        }
        return cachedSansLabel as FontType;
    }

    function sansMicro() as FontType {
        if (cachedSansMicro == null) {
            cachedSansMicro = WatchUi.loadResource(Rez.Fonts.sansMicro) as FontType;
        }
        return cachedSansMicro as FontType;
    }

    (:serifFont)
    function loadTime() as FontType {
        return WatchUi.loadResource(Rez.Fonts.serifTime) as FontType;
    }

    (:serifFont)
    function loadSmall() as FontType {
        return WatchUi.loadResource(Rez.Fonts.serifSmall) as FontType;
    }

    (:serifFont)
    function loadLabel() as FontType {
        return WatchUi.loadResource(Rez.Fonts.serifLabel) as FontType;
    }

    // Fallbacks for a device with no generated serif. Deliberately plain
    // — the look depends on the serif, and a stand-in should read as a
    // stand-in rather than pretend.
    (:serifFont)
    function loadMicro() as FontType {
        return WatchUi.loadResource(Rez.Fonts.serifMicro) as FontType;
    }

    (:noSerifFont)
    function loadTime() as FontType {
        var width = System.getDeviceSettings().screenWidth;
        if (width >= 400) { return Graphics.FONT_NUMBER_THAI_HOT; }
        if (width >= 280) { return Graphics.FONT_NUMBER_HOT; }
        return Graphics.FONT_NUMBER_MEDIUM;
    }

    (:noSerifFont)
    function loadSmall() as FontType {
        return Graphics.FONT_TINY;
    }

    (:noSerifFont)
    function loadLabel() as FontType {
        return Graphics.FONT_XTINY;
    }

    (:noSerifFont)
    function loadMicro() as FontType {
        return Graphics.FONT_XTINY;
    }

    // Called when the face is torn down so the sheets are not held
    // against the memory cap while another app runs.
    function release() as Void {
        cachedTime = null;
        cachedSmall = null;
        cachedLabel = null;
        cachedMicro = null;
        cachedSansTime = null;
        cachedSansSmall = null;
        cachedSansLabel = null;
        cachedSansMicro = null;
    }
}
