import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ReconFaceApp extends Application.AppBase {

    hidden var view as FaceView or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        view = new FaceView();
        return [view as FaceView];
    }

    // The demo switches are the only settings this face has, and they
    // only ever move in the simulator. Nothing needs rebuilding.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
