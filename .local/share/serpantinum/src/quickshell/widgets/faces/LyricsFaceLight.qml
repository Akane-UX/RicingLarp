import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"

// ─────────────────────────────────────────────────────────────────────────────
// LyricsFace.qml — Transparent lyrics overlay widget for Serpentinum
//
// Fetches synced lyrics from lrclib.net (same source as the `lirik` CLI tool)
// and displays the current line using MPRIS position. Fully transparent —
// no background, no border, only floating text.
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root
    anchors.fill: parent

    // ── Size constraints (used by Widget.qml / WidgetRegistry) ────────────────
    property real minWidth:  200
    property real minHeight: 48
    property real maxWidth:  99999
    property real maxHeight: 99999
    property real minAspect: 0
    property real maxAspect: 99999

    // ── Configurable appearance ───────────────────────────────────────────────
    // fontSize: controls lyric text size (dynamic by default, based on height)
    property real fontSize: Math.max(12, Math.min(40, root.height * 0.28))
    // alignment: Qt.AlignHCenter | Qt.AlignLeft | Qt.AlignRight
    property int  textAlign: Text.AlignHCenter
    // color: inherits from ThemeBackend but can be overridden
    property color textColor: ThemeBackend.text
    property color inactiveColor: ThemeBackend.subtext0

    // ── Show/hide next lyric line as a hint ───────────────────────────────────
    property bool showNextLine: false
    property real nextLineFontSize: Math.max(9, root.fontSize * 0.55)
    property color nextLineColor: Qt.rgba(
        ThemeBackend.subtext0.r,
        ThemeBackend.subtext0.g,
        ThemeBackend.subtext0.b,
        0.5
    )

    // ── Internal state ────────────────────────────────────────────────────────
    property var  lrcData:      []   // [{t: float, text: string}]
    property int  currentIndex: -1
    property string currentLine: ""
    property string nextLine:    ""
    property string lastSong:   ""
    property bool fetching:     false
    property bool hasLyrics:    true // false when not found

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null
        && player.playbackState !== MprisPlaybackState.Stopped
        && player.trackTitle !== ""

    // ── Track change detection ────────────────────────────────────────────────
    property string trackKey: isMediaActive
        ? ((MprisController.trackArtist || "") + "|" + (MprisController.trackTitle || ""))
        : ""

    onTrackKeyChanged: {
        if (trackKey !== "" && trackKey !== lastSong) {
            lastSong = trackKey;
            lrcData = [];
            currentLine = "";
            nextLine = "";
            currentIndex = -1;
            hasLyrics = true;
            if (!fetching) startFetch();
        } else if (trackKey === "") {
            lrcData = [];
            currentLine = "";
            nextLine = "";
            hasLyrics = true;
            lastSong = "";
        }
    }

    // ── Fetch lyrics via shell script ─────────────────────────────────────────
    // NOTE: command is assigned explicitly here (not via declarative binding)
    // so a widget created before MPRIS players appear (e.g. after daemon
    // restart) still fetches with the CURRENT artist/title, not stale empties.
    function scriptPath() {
        if (Caching.serpantinumDir) return Caching.serpantinumDir + "/quickshell/media/lyrics_fetch.sh";
        if (Caching.qsDir) return Caching.qsDir + "/media/lyrics_fetch.sh";
        return (Caching.home || "") + "/.local/share/serpantinum/src/quickshell/media/lyrics_fetch.sh";
    }

    function startFetch() {
        if (!isMediaActive || fetching) return;
        fetching = true;
        lyricFetchProc.command = [
            "bash",
            scriptPath(),
            MprisController.trackArtist || "",
            MprisController.trackTitle  || ""
        ];
        // Defer (re)start by one tick: toggling `running` false→true
        // synchronously is ignored by Quickshell's Process sometimes,
        // which left the widget stuck empty after a daemon restart.
        fetchRestartTimer.restart();
    }

    Timer {
        id: fetchRestartTimer
        interval: 50
        repeat: false
        onTriggered: {
            lyricFetchProc.running = false;
            lyricFetchProc.running = true;
        }
    }

    // Auto-retry while empty: if the first fetch raced MPRIS startup
    // (empty artist/title → no_track) the widget retries every 3s until
    // lyrics arrive, instead of staying blank forever after restart.
    Timer {
        id: fetchRetryTimer
        interval: 3000
        repeat: true
        running: root.isMediaActive && root.lrcData.length === 0 && !root.fetching && root.hasLyrics
        onTriggered: root.startFetch()
    }

    Process {
        id: lyricFetchProc
        // Safety net: if the script crashes with no stdout, onStreamFinished
        // never fires — reset `fetching` so the retry timer can try again.
        onExited: {
            if (root.fetching) Qt.callLater(function() {
                if (root.fetching && root.lrcData.length === 0) root.fetching = false;
            });
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.fetching = false;
                let txt = this.text.trim();
                if (!txt) return;
                try {
                    let obj = JSON.parse(txt);
                    if (obj.error === "not_found" || obj.error === "no_track") {
                        root.lrcData  = [];
                        root.hasLyrics = false;
                    } else if (Array.isArray(obj.lrc) && obj.lrc.length > 0) {
                        root.lrcData   = obj.lrc;
                        root.hasLyrics = true;
                    } else {
                        root.hasLyrics = false;
                    }
                } catch (e) {
                    root.hasLyrics = false;
                }
                root.syncLine();
            }
        }
    }

    // ── Sync current line to playback position ────────────────────────────────
    function syncLine() {
        if (!root.lrcData || root.lrcData.length === 0) {
            root.currentLine = "";
            root.nextLine    = "";
            root.currentIndex = -1;
            return;
        }
        // MprisController.livePosition is already in seconds (Quickshell converts internally)
        let pos = MprisController.livePosition;
        let idx = -1;
        for (let i = 0; i < root.lrcData.length; i++) {
            if (pos >= root.lrcData[i].t) {
                idx = i;
            } else {
                break;
            }
        }
        if (idx !== root.currentIndex) {
            root.currentIndex = idx;
            root.currentLine  = idx >= 0 ? (root.lrcData[idx].text || "") : "";
            let nextIdx = idx + 1;
            root.nextLine = (nextIdx < root.lrcData.length)
                ? (root.lrcData[nextIdx].text || "")
                : "";
        }
    }

    // ── Sync timer: 100 ms ────────────────────────────────────────────────────
    // NOTE: runs whenever media is active (not gated on lrcData), so a late
    // fetch result syncs to the correct line immediately on arrival.
    Timer {
        interval: 100
        repeat:   true
        running:  root.isMediaActive
        onTriggered: root.syncLine()
    }

    // ── Retry after song load ─────────────────────────────────────────────────
    Component.onCompleted: {
        if (root.trackKey !== "") root.lastSong = root.trackKey;
        if (root.isMediaActive) startFetch();
    }

    // ── UI: fully transparent, text only ─────────────────────────────────────
    // NOTE: clip is OFF on purpose — this is a transparent overlay, so a long
    // wrapped lyric overflows visibly instead of being cut at the widget edge.
    // Full text is always shown (no maximumLineCount / elide truncation).
    Item {
        id: lyricsContainer
        anchors.fill: parent
        clip: false

        // Current lyric line — vertically centered when next line is hidden, else
        // the pair (current + next) is centered as a unit via the wrapping Item
        Item {
            id: lyricsBlock
            anchors.left: parent.left
            anchors.right: parent.right
            // center the whole block vertically
            anchors.verticalCenter: parent.verticalCenter
            // height = current text's painted height + optional next line
            height: currentText.paintedHeight
                    + (nextText.visible ? lyricsColumn.spacing + nextText.paintedHeight : 0)

            Column {
                id: lyricsColumn
                width: parent.width
                spacing: Math.max(2, root.height * 0.05)

                // Current lyric line
                Text {
                    id: currentText
                    width: parent.width
                    text: {
                        if (!root.isMediaActive) return "";
                        if (root.fetching)       return "…";
                        if (!root.hasLyrics)     return "";
                        return root.currentLine;
                    }
                    font.family:    ThemeBackend.fontFamily
                    font.pixelSize: root.fontSize
                    font.weight:    Font.Light
                    color:          root.currentLine !== "" ? root.textColor : root.inactiveColor
                    horizontalAlignment: root.textAlign
                    wrapMode:       Text.WordWrap
                    // No maximumLineCount / elide: long lyrics wrap to as many
                    // lines as needed and stay fully visible (clip is off).

                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation {
                                target: currentText
                                property: "opacity"
                                to: 0
                                duration: 100
                                easing.type: Easing.OutQuad
                            }
                            PropertyAction {}
                            NumberAnimation {
                                target: currentText
                                property: "opacity"
                                to: 1
                                duration: 180
                                easing.type: Easing.InQuad
                            }
                        }
                    }
                }

                // Next lyric line (optional hint)
                Text {
                    id: nextText
                    width: parent.width
                    text: root.showNextLine ? root.nextLine : ""
                    font.family:    ThemeBackend.fontFamily
                    font.pixelSize: root.nextLineFontSize
                    font.weight:    Font.Medium
                    color:          root.nextLineColor
                    horizontalAlignment: root.textAlign
                    wrapMode:       Text.WordWrap
                    visible:        root.showNextLine && root.nextLine !== ""
                    opacity:        0.7
                }
            }
        }
    }
}
