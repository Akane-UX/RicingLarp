import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: visWindow

        required property var modelData

        screen: modelData
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-desktop-vis"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Ignore
        focusable: false

        // Posisi di bawah layar
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        // Tinggi window = tinggi max visualizer (20% layar)
        implicitWidth: modelData ? modelData.width : 1920
        implicitHeight: modelData ? Math.round(modelData.height * 0.20) : 216

        // Input pass-through
        mask: Region {}

        property int barCount: 120
        property bool visualiserEnabled: (Config.getSetting("desktopVisualiser", {"enabled": true}).enabled !== false)
        property bool shouldBeActive: MprisController.isPlaying && visualiserEnabled

        Component.onCompleted: {
            Cava.registerConsumer();
        }

        Component.onDestruction: {
            Cava.unregisterConsumer();
        }

        property var barLevels: {
            let source = Cava.barLevels;
            let count = barCount;
            let out = [];
            if (!source || source.length === 0) {
                for (let i = 0; i < count; i++) out.push(0.0);
                return out;
            }
            for (let i = 0; i < count; i++) {
                let norm = count > 1 ? (i / (count - 1)) : 0;
                let srcIdx = Math.min(source.length - 1,
                    Math.floor(Math.pow(norm, 1.4) * (source.length - 1)));
                let val = source[srcIdx] || 0.0;
                if (val < 0.03) {
                    val = 0.0;
                } else {
                    val = Math.pow((val - 0.03) / 0.97, 1.2);
                }
                out.push(val);
            }
            return out;
        }

        Item {
            id: visRoot
            anchors.fill: parent

            opacity: visWindow.shouldBeActive ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
            }

            property int halfCount: Math.floor(visWindow.barCount / 2)
            // Gap di tengah 22% lebar layar
            property real gapWidth: visWindow.implicitWidth * 0.22
            property real sideWidth: (visWindow.implicitWidth - gapWidth) / 2

            // Sisi KIRI — index 0 di kiri, terbesar di dekat tengah
            Row {
                id: leftRow
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: visRoot.sideWidth
                height: parent.height
                layoutDirection: Qt.RightToLeft

                spacing: 1

                Repeater {
                    model: visRoot.halfCount
                    delegate: Rectangle {
                        required property int index

                        property real level: (visWindow.barLevels && index < visWindow.barLevels.length)
                            ? visWindow.barLevels[index] : 0.0

                        width: Math.max(1, (leftRow.width / visRoot.halfCount) - 1)
                        height: Math.max(2, level * visWindow.implicitHeight)
                        anchors.bottom: parent.bottom
                        radius: width * 0.5

                        color: Qt.rgba(
                            ThemeBackend.text.r + (ThemeBackend.mauve.r - ThemeBackend.text.r) * level,
                            ThemeBackend.text.g + (ThemeBackend.mauve.g - ThemeBackend.text.g) * level,
                            ThemeBackend.text.b + (ThemeBackend.mauve.b - ThemeBackend.text.b) * level,
                            0.35 + level * 0.65
                        )

                        Behavior on height {
                            NumberAnimation { duration: 65; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }

            // Sisi KANAN — index halfCount di dekat tengah, terbesar di tengah
            Row {
                id: rightRow
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: visRoot.sideWidth
                height: parent.height
                layoutDirection: Qt.LeftToRight

                spacing: 1

                Repeater {
                    model: visRoot.halfCount
                    delegate: Rectangle {
                        required property int index

                        property real level: {
                            let idx = visRoot.halfCount + index;
                            return (visWindow.barLevels && idx < visWindow.barLevels.length)
                                ? visWindow.barLevels[idx] : 0.0;
                        }

                        width: Math.max(1, (rightRow.width / visRoot.halfCount) - 1)
                        height: Math.max(2, level * visWindow.implicitHeight)
                        anchors.bottom: parent.bottom
                        radius: width * 0.5

                        color: Qt.rgba(
                            ThemeBackend.text.r + (ThemeBackend.mauve.r - ThemeBackend.text.r) * level,
                            ThemeBackend.text.g + (ThemeBackend.mauve.g - ThemeBackend.text.g) * level,
                            ThemeBackend.text.b + (ThemeBackend.mauve.b - ThemeBackend.text.b) * level,
                            0.35 + level * 0.65
                        )

                        Behavior on height {
                            NumberAnimation { duration: 65; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
