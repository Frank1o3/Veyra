pragma Singleton
import Quickshell

Singleton {
    // Per-monitor control-center state: keyed by screen name.
    property var _openScreens: ({})

    function isOpen(screenName) {
        return !!_openScreens[screenName];
    }

    function setOpen(screenName, open) {
        let copy = Object.assign({}, _openScreens);
        if (open)
            copy[screenName] = true;
        else
            delete copy[screenName];
        _openScreens = copy;
    }

    function toggle(screenName) {
        setOpen(screenName, !isOpen(screenName));
    }

    function closeAll() {
        _openScreens = {};
    }
}
