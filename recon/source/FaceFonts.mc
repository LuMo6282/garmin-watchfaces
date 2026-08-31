import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// One typeface at four sizes. Clay carries two families because its
// three editorial layouts are built on a serif's colour; Recon is a
// single face and has no reason to hold a second sheet in memory.
//
// All four are Bahnschrift - DIN 1451 - subset to upper case and
// figures. See resources/fonts/fonts.xml for what each carries and
// tools/make_din_font.py to regenerate.
module FaceFonts {

    var cachedTime as FontType or Null = null;
    var cachedSmall as FontType or Null = null;
    var cachedLabel as FontType or Null = null;
    var cachedMicro as FontType or Null = null;

    function time() as FontType {
        if (cachedTime == null) {
            cachedTime = WatchUi.loadResource(Rez.Fonts.dinTime) as FontType;
        }
        return cachedTime as FontType;
    }

    function small() as FontType {
        if (cachedSmall == null) {
            cachedSmall = WatchUi.loadResource(Rez.Fonts.dinSmall) as FontType;
        }
        return cachedSmall as FontType;
    }

    function label() as FontType {
        if (cachedLabel == null) {
            cachedLabel = WatchUi.loadResource(Rez.Fonts.dinLabel) as FontType;
        }
        return cachedLabel as FontType;
    }

    function micro() as FontType {
        if (cachedMicro == null) {
            cachedMicro = WatchUi.loadResource(Rez.Fonts.dinMicro) as FontType;
        }
        return cachedMicro as FontType;
    }

    // Called when the face is torn down so the sheets are not held
    // against the memory cap while another app runs.
    function release() as Void {
        cachedTime = null;
        cachedSmall = null;
        cachedLabel = null;
        cachedMicro = null;
    }
}
