import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../reusables"

PanelWindow {
    id: window

    WlrLayershell.namespace: "workspace-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore
    focusable: true
    screen: Quickshell.primaryScreen || null

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    property bool isVisible: false
    visible: isVisible

    property int selectedIndex: 0
    property var workspacesList: []
    property string previewDir: "/tmp/serpantinum_ws_preview"
    property int previewEpoch: 0
    property bool isCapturing: false

    function s(val) {
        return typeof Scaler !== "undefined" ? Scaler.s(val) : val;
    }

    function updateWorkspaces() {
        var count = 8;
        if (typeof Config !== "undefined" && Config.getSetting)
            count = Config.getSetting("bar.workspaceCount", 8);
        var list = [];
        var activeId = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.activeWorkspace.id : 1;
        var selIdx = 0;

        for (var i = 1; i <= count; i++) {
            var apps = [];
            if (Hyprland.toplevels) {
                var clients = Hyprland.toplevels.values.filter(function(c) {
                    return c.workspace && c.workspace.id === i;
                });
                for (var j = 0; j < clients.length; j++) {
                    apps.push(clients[j].initialClass || clients[j].class || "app");
                }
            }
            list.push({
                id: i,
                active: i === activeId,
                apps: apps,
                previewPath: previewDir + "/" + i + ".png"
            });
            if (i === activeId) selIdx = i - 1;
        }
        workspacesList = list;
        selectedIndex = selIdx;
    }

    function show() {
        updateWorkspaces();
        // Refresh images dari cache yang sudah ada
        previewEpoch = previewEpoch + 1;
        isVisible = true;
        // Jalankan capture semua workspace di background
        // Setelah selesai, previewEpoch naik lagi dan gambar diperbarui
        if (!isCapturing) {
            isCapturing = true;
            captureAllProcess.running = true;
        }
    }

    function hide() { isVisible = false; }

    function toggle() {
        if (isVisible) hide(); else show();
    }

    function selectCurrent() {
        if (selectedIndex >= 0 && selectedIndex < workspacesList.length) {
            var targetId = workspacesList[selectedIndex].id;
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + targetId + " })");
        }
        hide();
    }

    function next() {
        if (!isVisible) show();
        if (workspacesList.length > 0)
            selectedIndex = (selectedIndex + 1) % workspacesList.length;
    }

    function prev() {
        if (!isVisible) show();
        if (workspacesList.length > 0)
            selectedIndex = (selectedIndex - 1 + workspacesList.length) % workspacesList.length;
    }

    // Capture semua workspace saat dibuka
    Process {
        id: captureAllProcess
        running: false
        command: ["bash", window.previewDir.replace("/tmp/serpantinum_ws_preview",
            "/home/avrlln/.local/share/serpantinum/src/scripts/ws_capture_all.sh")]
        onExited: function(exitCode) {
            window.isCapturing = false;
            // Refresh semua gambar setelah capture selesai
            window.previewEpoch = window.previewEpoch + 1;
            // Update workspace list (kembali ke ws asal setelah script)
            window.updateWorkspaces();
        }
    }

    // Capture current workspace saat berpindah (untuk cache)
    Connections {
        target: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.activeWorkspace : null
        function onIdChanged() {
            var wsId = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.activeWorkspace.id : 1;
            captureOneProcess.command = ["bash", "-c",
                "mkdir -p /tmp/serpantinum_ws_preview && " +
                "grim -o eDP-1 -s 0.25 /tmp/serpantinum_ws_preview/" + wsId + ".png 2>/dev/null"
            ];
            captureOneProcess.running = true;
        }
    }

    Process {
        id: captureOneProcess
        running: false
        command: []
        onExited: function(exitCode) {
            if (exitCode === 0) window.previewEpoch = window.previewEpoch + 1;
        }
    }

    Component.onCompleted: {
        captureOneProcess.command = ["bash", "-c",
            "mkdir -p /tmp/serpantinum_ws_preview && " +
            "grim -o eDP-1 -s 0.25 /tmp/serpantinum_ws_preview/1.png 2>/dev/null"
        ];
        captureOneProcess.running = true;
    }

    IpcHandler {
        target: "workspace_switcher"
        function toggle(): void { window.toggle(); }
        function show(): void   { window.show();   }
        function hide(): void   { window.hide();   }
        function next(): void   { window.next();   }
        function prev(): void   { window.prev();   }
        function select(): void { window.selectCurrent(); }
    }

    Item {
        anchors.fill: parent
        focus: window.isVisible
        opacity: window.isVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Keys.onPressed: function(event) {
            if (!window.isVisible) return;
            switch (event.key) {
                case Qt.Key_Escape:  window.hide();          event.accepted = true; break;
                case Qt.Key_Right:
                case Qt.Key_Down:
                case Qt.Key_Tab:     window.next();          event.accepted = true; break;
                case Qt.Key_Left:
                case Qt.Key_Up:      window.prev();          event.accepted = true; break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:   window.selectCurrent(); event.accepted = true; break;
            }
        }

        // Background dim
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            MouseArea { anchors.fill: parent; onClicked: window.hide() }
        }

        // Panel
        Rectangle {
            id: container
            anchors.centerIn: parent
            width:  Math.min(parent.width * 0.94, window.s(1200))
            height: window.s(240)
            radius: window.s(16)
            color:  Qt.alpha(ThemeBackend.mantle || "#11111b", 0.95)
            border.color: Qt.alpha(ThemeBackend.mauve || "#cba6f7", 0.3)
            border.width: 1

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: window.s(14)
                spacing: window.s(10)

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(18)
                    Text {
                        text: "Pratinjau Workspace"
                        font.family: ThemeBackend.fontFamily || "sans-serif"
                        font.weight: Font.Bold
                        font.pixelSize: window.s(13)
                        color: ThemeBackend.text || "#cdd6f4"
                    }
                    Item { Layout.fillWidth: true }

                    // Loading indicator
                    Row {
                        spacing: window.s(6)
                        visible: window.isCapturing
                        Rectangle {
                            width: window.s(6); height: width; radius: width/2
                            color: ThemeBackend.yellow || "#f9e2af"
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }
                        Text {
                            text: "Mengambil preview..."
                            font.family: ThemeBackend.fontFamily || "sans-serif"
                            font.pixelSize: window.s(10)
                            color: ThemeBackend.yellow || "#f9e2af"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        visible: !window.isCapturing
                        text: "← → / Tab  •  Enter untuk pindah  •  Esc untuk tutup"
                        font.family: ThemeBackend.fontFamily || "sans-serif"
                        font.pixelSize: window.s(10)
                        color: ThemeBackend.subtext0 || "#a6adc8"
                    }
                }

                // Cards
                Row {
                    id: cardsRow
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: window.s(8)

                    Repeater {
                        model: window.workspacesList

                        delegate: Item {
                            id: cardWrapper
                            required property var modelData
                            required property int index

                            width:  (cardsRow.width - cardsRow.spacing * (window.workspacesList.length - 1))
                                    / window.workspacesList.length
                            height: cardsRow.height

                            property bool isSelected: index === window.selectedIndex
                            property bool isActive:   modelData.active

                            scale: isSelected ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                radius: window.s(9)
                                color: cardWrapper.isSelected
                                    ? Qt.alpha(ThemeBackend.mauve || "#cba6f7", 0.14)
                                    : Qt.alpha(ThemeBackend.surface0 || "#313244", 0.65)
                                border.color: cardWrapper.isSelected
                                    ? (ThemeBackend.mauve || "#cba6f7")
                                    : cardWrapper.isActive
                                        ? (ThemeBackend.blue || "#89b4fa")
                                        : Qt.alpha(ThemeBackend.surface1 || "#45475a", 0.35)
                                border.width: cardWrapper.isSelected ? 2 : 1
                                clip: true
                                Behavior on border.color { ColorAnimation { duration: 130 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: window.s(5)
                                    spacing: window.s(3)

                                    // Preview landscape
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: window.s(5)
                                        color: Qt.rgba(0, 0, 0, 0.45)
                                        clip: true

                                        Image {
                                            id: previewImg
                                            anchors.fill: parent
                                            source: "file://" + modelData.previewPath + "?v=" + window.previewEpoch
                                            fillMode: Image.PreserveAspectCrop
                                            cache: false
                                            smooth: true
                                            asynchronous: true
                                        }

                                        // Fallback saat belum ada screenshot
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: window.s(5)
                                            color: "transparent"
                                            visible: previewImg.status !== Image.Ready

                                            // Kosong
                                            Text {
                                                anchors.centerIn: parent
                                                visible: modelData.apps.length === 0
                                                text: "Kosong"
                                                font.family: ThemeBackend.fontFamily || "sans-serif"
                                                font.pixelSize: window.s(10)
                                                color: Qt.alpha(ThemeBackend.subtext0 || "#a6adc8", 0.35)
                                            }

                                            // Ada app — tampilkan sebagai chip
                                            Column {
                                                anchors.centerIn: parent
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.leftMargin: window.s(6)
                                                anchors.rightMargin: window.s(6)
                                                spacing: window.s(4)
                                                visible: modelData.apps.length > 0

                                                Repeater {
                                                    model: modelData.apps.slice(0, 4)
                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        required property int index
                                                        width: parent.width
                                                        height: window.s(18)
                                                        radius: window.s(4)
                                                        color: index === 0
                                                            ? Qt.alpha(ThemeBackend.mauve || "#cba6f7", 0.22)
                                                            : Qt.alpha(ThemeBackend.surface1 || "#45475a", 0.5)
                                                        Text {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.leftMargin: window.s(5)
                                                            anchors.rightMargin: window.s(5)
                                                            text: modelData
                                                            font.family: ThemeBackend.fontFamily || "sans-serif"
                                                            font.pixelSize: window.s(9)
                                                            color: index === 0
                                                                ? (ThemeBackend.mauve || "#cba6f7")
                                                                : (ThemeBackend.subtext1 || "#bac2de")
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }

                                                Text {
                                                    visible: modelData.apps.length > 4
                                                    text: "+ " + (modelData.apps.length - 4) + " lagi"
                                                    font.family: ThemeBackend.fontFamily || "sans-serif"
                                                    font.pixelSize: window.s(8)
                                                    color: Qt.alpha(ThemeBackend.subtext0 || "#a6adc8", 0.5)
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                        }
                                    }

                                    // Footer
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: window.s(14)
                                        Text {
                                            text: "WS " + modelData.id
                                            font.family: ThemeBackend.fontFamily || "sans-serif"
                                            font.weight: Font.Bold
                                            font.pixelSize: window.s(9)
                                            color: cardWrapper.isSelected
                                                ? (ThemeBackend.mauve || "#cba6f7")
                                                : (ThemeBackend.subtext1 || "#bac2de")
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            width: window.s(6); height: width
                                            radius: width / 2
                                            color: ThemeBackend.green || "#a6e3a1"
                                            visible: cardWrapper.isActive
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: window.selectedIndex = index
                                onClicked: {
                                    window.selectedIndex = index;
                                    window.selectCurrent();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
