import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ClayFaceApp extends Application.AppBase {

    hidden var view as FaceView or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        view = new FaceView();
        return [view as FaceView];
    }

    function onSettingsChanged() as Void {
        if (view != null) {
            (view as FaceView).buildRenderer();
        }
        WatchUi.requestUpdate();
    }
}
