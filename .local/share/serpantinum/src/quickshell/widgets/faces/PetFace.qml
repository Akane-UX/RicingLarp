import QtQuick
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 150
    property real minHeight: 72
    property real maxWidth: 9999
    property real maxHeight: 9999
    property real minAspect: 1.0
    property real maxAspect: 99.0
    property bool isRound: false

    property string petState: "IDLE"
    property string assetDir: "file:///home/avrlln/DesktopPet/assets/"
    
    // Internal Cat position inside the widget
    property real catX: (width - 72) / 2
    property real speed: 2

    AnimatedImage {
        id: catAnim
        x: (root.width - 72) / 2
        y: root.height - 72
        width: 72
        height: 72
        source: {
            if (root.petState === "IDLE") return root.assetDir + "idle.gif"
            if (root.petState === "WALK_LEFT") return root.assetDir + "walk_left.gif"
            if (root.petState === "WALK_RIGHT") return root.assetDir + "walk_right.gif"
            if (root.petState === "SLEEP") return root.assetDir + "sleep.gif"
            if (root.petState === "DRAG") return root.assetDir + "drag.png"
            return root.assetDir + "idle.gif"
        }
        fillMode: Image.PreserveAspectFit
        playing: root.petState !== "DRAG"
        
        // Animasi Gravitasi (Jatuh)
        NumberAnimation on y {
            id: gravityAnim
            running: false
            to: root.height - 72
            duration: Math.max(300, (root.height - 72 - catAnim.y) * 1.5) // Kecepatan proporsional
            easing.type: Easing.OutBounce // Efek memantul saat menyentuh tanah
        }
        
        MouseArea {
            anchors.fill: parent
            drag.target: catAnim
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.maximumX: root.width - catAnim.width
            drag.minimumY: 0
            drag.maximumY: root.height - catAnim.height
            
            onPressed: {
                root.petState = "DRAG"
                gravityAnim.stop()
            }
            onReleased: {
                root.petState = "IDLE"
                gravityAnim.to = root.height - 72
                gravityAnim.start()
            }
            onDoubleClicked: {
                root.petState = "SLEEP"
            }
        }
    }

    // Logic Timer (Decision)
    Timer {
        interval: 3000
        running: root.petState !== "DRAG"
        repeat: true
        onTriggered: {
            // Jika sedang tidur, lebih susah dibangunin (peluang bangun kecil)
            if (root.petState === "SLEEP" && Math.random() < 0.7) {
                return; 
            }
            
            let actions = ["IDLE", "WALK_LEFT", "WALK_RIGHT", "SLEEP"]
            let weights = [0.3, 0.25, 0.25, 0.2]
            
            let rand = Math.random()
            let cumulative = 0
            for (let i=0; i<actions.length; i++) {
                cumulative += weights[i]
                if (rand <= cumulative) {
                    root.petState = actions[i]
                    break
                }
            }
        }
    }

    // Movement Timer (60FPS)
    Timer {
        interval: 16
        running: (root.petState === "WALK_LEFT" || root.petState === "WALK_RIGHT") && root.petState !== "DRAG"
        repeat: true
        onTriggered: {
            if (root.petState === "WALK_LEFT") {
                catAnim.x -= root.speed
                if (catAnim.x <= 0) {
                    root.petState = "WALK_RIGHT"
                }
            } else if (root.petState === "WALK_RIGHT") {
                catAnim.x += root.speed
                if (catAnim.x >= root.width - catAnim.width) {
                    root.petState = "WALK_LEFT"
                }
            }
        }
    }
}
