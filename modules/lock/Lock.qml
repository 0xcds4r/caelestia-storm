pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.misc

Scope {
    id: lockScope

    property alias lock: lock

    // Timestamp of the last successful unlock; logind/hypridle can repeat the Lock signal right
    // after it, which re-opened the lock screen the moment it was dismissed.
    property double unlockedAt: 0

    // Single entry point for every lock request (shortcut, IPC, logind, session menu). A request
    // that arrives right after an unlock is a repeat and is dropped.
    function requestLock(debounceMs: int): void {
        if (lock.locked)
            return;

        const since = Date.now() - lockScope.unlockedAt;
        if (debounceMs > 0 && lockScope.unlockedAt > 0 && since < debounceMs)
            return;

        lock.locked = true;
    }

    WlSessionLock {
        id: lock

        signal unlock

        onLockedChanged: {
            if (locked)
                return;

            lockScope.unlockedAt = Date.now();
            // Clear logind's LockedHint as well, otherwise the session stays "locked" there and a
            // repeated Lock signal re-opens the screen the moment it was dismissed.
            unlockHint.running = true;
        }

        LockSurface {
            lock: lock
            pam: pam
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    Process {
        id: unlockHint

        command: ["sh", "-c", "loginctl unlock-session 2>/dev/null || true"]
    }

    // The unlock is animated, and the animation flips `locked` to false at the very end. If it is
    // interrupted (a monitor changes, a surface is re-created) the lock stayed up forever, so a
    // fallback forces the state after the animation had every chance to finish.
    Timer {
        id: unlockFallback

        interval: 900
        repeat: false

        onTriggered: {
            if (lock.locked)
                lock.locked = false;
        }
    }

    Connections {
        function onUnlock(): void {
            unlockFallback.restart();
        }

        target: lock
    }

    Loader {
        asynchronous: true
        active: true
        onLoaded: active = false

        // Force a load of a screencopy so the one in the lock works
        // My guess is the ICC backend loads async on first request, which if the lock is
        // the first request it fails to capture (because it's async and the compositor
        // refuses capture when locked)
        sourceComponent: ScreencopyView {
            captureSource: Quickshell.screens[0]
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "lock"
        description: "Lock the current session"
        onPressed: lockScope.requestLock(0)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    IpcHandler {
        function lock(): void {
            lockScope.requestLock(0);
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }

        target: "lock"
    }
}
