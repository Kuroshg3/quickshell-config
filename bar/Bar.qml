pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Scope {
    id: root
    property var theme: DefaultTheme {}
    property string font: "JetbrainsMono Nerd Font"
    property bool barVisible: true
    readonly property string username: Quickshell.env("USER") ?? "unknown"

    // MPRIS active nowPlaying
    property var activeNowPlaying: {
        const nowPlayings = Mpris.players.values;
        if (!nowPlayings || nowPlayings.length === 0)
            return null;
        for (const p of nowPlayings) {
            if (p.playbackState === MprisPlaybackState.Playing)
                return p;
        }
        return nowPlayings[0];
    }
    property real activeNowPlayingVolume: (root.activeNowPlaying.volume * 100).toFixed(2)

    IpcHandler {
        target: "bar"
        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // Brightness state
    property real brightnessValue: 0
    property real brightnessMax: 1

    FileView {
        id: brightnessFile
        path: ""
        watchChanges: true
        onFileChanged: brightnessReadProc.running = true
    }

    Process {
        id: brightnessReadProc
        command: ["brightnessctl", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(text.trim());
                if (!isNaN(val) && root.brightnessMax > 0)
                    root.brightnessValue = val / root.brightnessMax;
            }
        }
    }

    Process {
        id: brightnessSetProc
        running: false
    }

    Process {
        id: backlightDiscovery
        command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2) {
                    const max = parseInt(lines[1]);
                    if (!isNaN(max) && max > 0)
                        root.brightnessMax = max;
                    brightnessFile.path = lines[0];
                    brightnessReadProc.running = true;
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            visible: root.barVisible

            property var per_monitor_scale_num: Math.pow(modelData.width / 1920, 0.3).toFixed(2)

            function scale_per_monitor(size) {
                return Math.round(size * per_monitor_scale_num);
            }

            anchors {
                top: true
                //left: true
                //right: true
            }
            width: modelData.width * 0.9
            implicitHeight: Math.pow(modelData.height, 1 / 2)
            //implicitHeight: Math.pow(1080, 1/2) ~ 33

            color: "transparent"

            Rectangle {
                anchors.fill: parent

                color: root.theme.bgBase
                bottomRightRadius: 10
                bottomLeftRadius: 10

                // Left section: kg icon + Workspaces + Now Playing
                Row {
                    id: leftSection
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: panel.scale_per_monitor(8)
                    spacing: 10

                    // user Logo
                    Rectangle {
                        id: userIcon
                        height: parent.height
                        implicitWidth: userText.width
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"

                        Text {
                            id: userText
                            text: root.username.toUpperCase()
                            anchors.centerIn: parent
                            //height: 16
                            font.family: "Tsushima3"
                            font.pixelSize: panel.scale_per_monitor(20)
                            color: root.theme.textPrimary

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {} else if (mouse.button === Qt.RightButton) {}
                                }
                            }
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 1
                                    duration: 1500
                                    easing.type: Easing.InExpo
                                }
                                PauseAnimation {
                                    duration: 6000
                                }
                                NumberAnimation {
                                    to: 0.07
                                    duration: 2000
                                    easing.type: Easing.OutInElastic
                                }
                                PauseAnimation {
                                    duration: 1500
                                }
                            }
                        }
                    }

                    // Workspaces
                    Row {
                        id: workspacesContainer
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: Hyprland.workspaces

                            Rectangle {
                                id: wsPill
                                required property var modelData

                                property bool urgentBlink: true

                                property bool isWsSpecial: modelData.id < 0
                                property bool isWsNowToplevel: Hyprland.activeToplevel.workspace.id === modelData.id
                                property bool isWsFocused: modelData.focused
                                property bool isWsNowUrgent: modelData.urgent && urgentBlink

                                //visible: modelData.focused || modelData.id > 0

                                Accessible.role: Accessible.Button
                                Accessible.name: "Workspace " + modelData.id + (modelData.focused ? ", active" : "") + (modelData.urgent ? ", urgent" : "")

                                width: ((isWsFocused || isWsNowToplevel) ? 20 : 18) + ((isWsSpecial) ? 10 : 0)
                                height: 20
                                radius: 5
                                color: (isWsSpecial && isWsNowToplevel) ? root.theme.accentGreen : (isWsFocused) ? root.theme.accentPrimary : (isWsNowUrgent) ? root.theme.accentOrange : root.theme.bgSurface
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    running: wsPill.modelData.urgent && !wsPill.modelData.focused

                                    PropertyAction {
                                        target: wsPill
                                        property: "urgentBlink"
                                        value: true
                                    }
                                    PauseAnimation {
                                        duration: 500
                                    }
                                    PropertyAction {
                                        target: wsPill
                                        property: "urgentBlink"
                                        value: false
                                    }
                                    PauseAnimation {
                                        duration: 500
                                    }

                                    onStopped: wsPill.urgentBlink = false
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: (wsPill.isWsSpecial) ? wsPill.modelData.name.replace(/special:(\w)\w*/g, "s.$1").toUpperCase() : wsPill.modelData.id
                                    color: (wsPill.isWsFocused || (wsPill.isWsSpecial && wsPill.isWsNowToplevel)) ? root.theme.bgBase : root.theme.textPrimary
                                    font.pixelSize: panel.scale_per_monitor(14)
                                    font.family: root.font
                                    font.bold: (wsPill.isWsFocused | (wsPill.isWsSpecial && wsPill.isWsNowToplevel))
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wsPill.modelData.activate()
                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }
                            }
                        }
                    }

                    // active window title display
                    Rectangle {
                        id: windowNameContainer
                        height: parent.height
                        //width: parent.right - workspacesContainer.right
                        width: (windowNameText.width > 200) ? 200 : windowNameText.width
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        clip: true
                        visible: Hyprland.activeToplevel

                        Text {
                            //height: parent.height
                            //width: Math.min(implicitWidth, 200)
                            id: windowNameText
                            anchors.verticalCenter: parent.verticalCenter

                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Active window: " + text

                            text: "[" + (windowNameContainer.visible ? Hyprland.activeToplevel.title : "") + "]"
                            color: root.theme.textPrimary
                            font.pixelSize: panel.scale_per_monitor(13)
                            font.family: root.font

                            //elide: Text.ElideRight

                            x: 0
                            readonly property bool windowNameNeedsAnimation: windowNameText.width > 200

                            readonly property real maxScrollX: windowNameContainer.width - implicitWidth

                            SequentialAnimation {
                                id: activeWindowAnim
                                running: windowNameText.windowNameNeedsAnimation && !mouseWindowName.containsMouse
                                loops: Animation.Infinite

                                PauseAnimation {
                                    duration: 500
                                }
                                NumberAnimation {
                                    target: windowNameText
                                    property: "x"
                                    to: windowNameText.maxScrollX
                                    duration: Math.abs(windowNameText.maxScrollX) * 50
                                    easing.type: Easing.Linear
                                }

                                PauseAnimation {
                                    duration: 2500
                                }

                                NumberAnimation {
                                    target: windowNameText
                                    property: "x"
                                    to: 0
                                    duration: Math.abs(windowNameText.maxScrollX) * 50
                                    easing.type: Easing.Linear
                                }
                                PauseAnimation {
                                    duration: 2000
                                }
                            }
                            onWindowNameNeedsAnimationChanged: {
                                if (!windowNameNeedsAnimation) {
                                    activeWindowAnim.stop();
                                    windowNameText.x = 0;
                                }
                            }
                        }
                        MouseArea {
                            id: mouseWindowName
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (windowNameText.windowNameNeedsAnimation) ? Qt.SplitHCursor : undefined
                            onWheel: wheel => {
                                windowNameText.x = Math.min(0, Math.max(windowNameText.maxScrollX, windowNameText.x + wheel.angleDelta.y / 7.5));
                                activeWindowAnim.stop();
                            }
                        }
                    }
                }

                // Center section: Window Title (truly centered in bar)
                Item {
                    anchors.centerIn: parent
                    height: parent.height
                    //width: Math.max(0, parent.width - 2 * Math.max(leftSection.width, rightSection.width) - 32)

                    // Time
                    Rectangle {
                        anchors.centerIn: parent
                        height: 24
                        width: timeDate.width + 16
                        radius: 6
                        color: root.theme.bgSurface

                        Row {
                            id: timeDate
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                color: root.theme.accentPrimary
                                font.pixelSize: panel.scale_per_monitor(12)
                                font.family: root.font
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Time.timeString
                                color: root.theme.textPrimary
                                font.pixelSize: panel.scale_per_monitor(16)
                                font.family: "ProFont IIX Nerd Font"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Time.dateString
                                color: root.theme.textSecondary
                                font.pixelSize: panel.scale_per_monitor(13)
                                font.family: "ProFont IIX Nerd Font"
                            }
                        }
                    }
                }

                // Right section: nowPlaying + System Tray + System Info
                Row {
                    id: rightSection
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 6
                    spacing: 8

                    // Now Playing
                    Rectangle {
                        id: nowPlayingContainer
                        //property bool small_state_conditions: implicitWidth < 100 || !mouseNowPlaying.containsMouse
                        property bool isNowPlaying: root.activeNowPlaying && root.activeNowPlaying.isPlaying
                        property bool isAnyNameAvailable: nowPlayingTitleText.text !== ""
                        property string nowPlayingTitle: {
                            if (!root.activeNowPlaying)
                                return "";
                            const artist = root.activeNowPlaying.trackArtist || "";
                            const title = root.activeNowPlaying.trackTitle || "";
                            return artist ? artist + " - " + title : title;
                        }

                        height: 24
                        implicitWidth: panel.scale_per_monitor(100)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 8
                        color: root.theme.bgSelected
                        visible: root.activeNowPlaying !== null

                        Accessible.role: Accessible.Button
                        Accessible.name: {
                            if (!root.activeNowPlaying)
                                return "No media";
                            const artist = root.activeNowPlaying.trackArtist || "";
                            const title = root.activeNowPlaying.trackTitle || "";
                            return "Now playing: " + (artist ? artist + " - " : "") + title;
                        }
                        Row {
                            id: nowPlayingRow
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                id: nowPlayingIconText
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                text: (nowPlayingContainer.isNowPlaying) ? "󰏤" : "󰐊"
                                color: root.theme.accentPrimary
                                font.pixelSize: panel.scale_per_monitor(18)
                                font.family: root.font
                            }

                            Rectangle {
                                id: nowPlayingTitleContainer
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                width: parent.width - nowPlayingIconText.width - parent.spacing
                                height: parent.height
                                color: "transparent"
                                clip: true
                                // visible: false

                                Text {
                                    id: nowPlayingTitleText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (nowPlayingVolumeResetTimer.running) ? "Vol: " + (Math.round(root.activeNowPlaying.volume * 100)).toString() : nowPlayingContainer.nowPlayingTitle
                                    color: root.theme.textPrimary
                                    font.pixelSize: panel.scale_per_monitor(14)
                                    font.family: root.font
                                    //wrapMode: text.war

                                    x: 0

                                    readonly property real maxScrollX: parent.width - implicitWidth

                                    SequentialAnimation {
                                        id: nowPlayingAnim
                                        running: nowPlayingContainer.isNowPlaying && !mouseNowPlaying.containsMouse && !nowPlayingVolumeResetTimer.running
                                        loops: Animation.Infinite
                                        readonly property real animationDuration: Math.abs(nowPlayingTitleText.maxScrollX) * 40

                                        PauseAnimation {
                                            duration: 500
                                        }

                                        NumberAnimation {
                                            target: nowPlayingTitleText
                                            property: "x"
                                            to: nowPlayingTitleText.maxScrollX
                                            duration: nowPlayingAnim.animationDuration
                                            easing.type: Easing.Linear
                                        }

                                        PauseAnimation {
                                            duration: 1500
                                        }

                                        NumberAnimation {
                                            target: nowPlayingTitleText
                                            property: "x"
                                            to: 0
                                            duration: nowPlayingAnim.animationDuration
                                            easing.type: Easing.Linear
                                        }
                                        PauseAnimation {
                                            duration: 1000
                                        }
                                    }
                                }
                            }
                        }
                        onIsNowPlayingChanged: {
                            nowPlayingTitleText.x = 0;
                            nowPlayingAnim.stop();
                        }
                        Timer {
                            id: nowPlayingVolumeResetTimer
                            interval: 2000
                            repeat: false
                        }

                        MouseArea {
                            id: mouseNowPlaying
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    root.activeNowPlaying.togglePlaying();
                                }
                            //else if (mouse.button === Qt.RightButton) {
                            ////if (nowPlayingContainer.width === nowPlayingTitleText.width)
                            //nowPlayingContainer.width = nowPlayingTitleText.width;
                            //}
                            }
                            onWheel: mouse => {
                                //nowPlayingTitleText.x = Math.min(0, Math.max(nowPlayingTitleText.maxScrollX, nowPlayingTitleText.x + mouse.angleDelta.y / 10));
                                root.activeNowPlaying.volume = Math.max(0, Math.min(100, root.activeNowPlaying.volume * 100 + Math.sign(mouse.angleDelta.y) * 5)) / 100;
                                nowPlayingAnim.stop();
                                nowPlayingTitleText.x = 0;
                                nowPlayingVolumeResetTimer.restart();
                            }
                        }
                    }

                    // System Tray
                    // There's an issue that some tray not display correctly.
                    // https://github.com/quickshell-mirror/quickshell/issues/26
                    // https://github.com/quickshell-mirror/quickshell/pull/777
                    Rectangle {
                        implicitHeight: 24
                        implicitWidth: trayIcons.implicitWidth + 4
                        radius: 8
                        color: root.theme.bgSurface

                        RowLayout {
                            id: trayIcons
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: SystemTray.items

                                MouseArea {
                                    id: trayDelegate
                                    cursorShape: Qt.PointingHandCursor
                                    required property SystemTrayItem modelData

                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData.tooltipTitle || modelData.title || "System tray item"

                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24

                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                                    onClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton) {
                                            modelData.activate();
                                        } else if (mouse.button === Qt.RightButton) {
                                            if (modelData.hasMenu) {
                                                menuAnchor.open();
                                            }
                                        } else if (mouse.button === Qt.MiddleButton) {
                                            modelData.secondaryActivate();
                                        }
                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        source: trayDelegate.modelData.icon
                                        implicitSize: 16
                                    }

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        menu: trayDelegate.modelData.menu

                                        anchor.window: trayDelegate.QsWindow.window
                                        anchor.adjustment: PopupAdjustment.Flip
                                        anchor.onAnchoring: {
                                            const window = trayDelegate.QsWindow.window;
                                            const widgetRect = window.contentItem.mapFromItem(trayDelegate, 0, trayDelegate.height, trayDelegate.width, trayDelegate.height);
                                            menuAnchor.anchor.rect = widgetRect;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // System Info
                    Row {
                        id: sysInfo

                        readonly property color batteryColor: {
                            if (SystemInfo.batteryCharging)
                                return root.theme.accentGreen;
                            if (SystemInfo.batteryLevelRaw > 20)
                                return root.theme.batteryGood;
                            if (SystemInfo.batteryLevelRaw > 10)
                                return root.theme.batteryWarning;
                            return root.theme.batteryCritical;
                        }

                        spacing: 4

                        //// CPU
                        //Rectangle {
                        //height: 24
                        //width: cpuContent.width + 12
                        //radius: 12
                        //color: root.theme.bgSurface
                        //Accessible.role: Accessible.StaticText
                        //Accessible.name: "CPU: " + SystemInfo.cpuUsage

                        //Row {
                        //id: cpuContent
                        //anchors.centerIn: parent
                        //spacing: 6

                        //Text {
                        //anchors.verticalCenter: parent.verticalCenter
                        //text: "󰻠"
                        //color: root.theme.accentOrange
                        //font.pixelSize: panel.scale_per_monitor(14)
                        //font.family: root.font
                        //}
                        //Text {
                        //anchors.verticalCenter: parent.verticalCenter
                        //text: SystemInfo.cpuUsage
                        //color: root.theme.textPrimary
                        //font.pixelSize: panel.scale_per_monitor(11)
                        //font.family: root.font
                        //}
                        //}
                        //}

                        // Temperature
                        Rectangle {
                            height: 24
                            width: tempContent.width + 14
                            radius: 8
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Temperature: CPU: " + SystemInfo.temperature_cpu + " GPU: " + SystemInfo.temperature_gpu

                            Row {
                                id: tempContent
                                anchors.centerIn: parent
                                spacing: 6
                                property var data_types: []

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰔏"
                                    color: root.theme.accentRed
                                    font.pixelSize: panel.scale_per_monitor(16)
                                    font.family: root.font
                                }
                                Text {
                                    id: tempContentText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "CPU: " + SystemInfo.temperature_cpu + " GPU: " + SystemInfo.temperature_gpu
                                    color: root.theme.textPrimary
                                    visible: false
                                    font.pixelSize: panel.scale_per_monitor(14)
                                    font.family: root.font
                                }
                            }
                            MouseArea {
                                id: mouseTemp
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        tempContentText.visible = !tempContentText.visible;
                                    } else if (mouse.button === Qt.RightButton) {}
                                }
                            }
                        }

                        // Volume
                        Rectangle {
                            height: 24
                            width: volContent.width + 12
                            radius: 8
                            color: root.theme.bgSurface

                            Accessible.role: Accessible.StaticText
                            Accessible.name: {
                                const sink = Pipewire.defaultAudioSink;
                                if (!sink || !sink.audio)
                                    return "Volume";
                                if (sink.audio.muted)
                                    return "Volume: muted";
                                return "Volume: " + Math.round(sink.audio.volume * 100) + "%";
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutExpo
                                }
                            }
                            Row {
                                id: volContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        const sink = Pipewire.defaultAudioSink;
                                        if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0)
                                            return "󰖁";
                                        if (sink.audio.volume < 0.33)
                                            return "󰕿";
                                        if (sink.audio.volume < 0.66)
                                            return "󰖀";
                                        return "󰕾";
                                    }
                                    color: {
                                        //const sink = Pipewire.defaultAudioSink;
                                        //if (!sink || !sink.audio || sink.audio.muted)
                                        //return root.theme.textMuted;
                                        return root.theme.accentPrimary;
                                    }
                                    font.pixelSize: panel.scale_per_monitor(18)
                                    font.family: root.font
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        const sink = Pipewire.defaultAudioSink;
                                        if (!sink || !sink.audio)
                                            return "–";
                                        if (sink.audio.muted)
                                            return "Mute";
                                        return Math.round(sink.audio.volume * 100) + "%";
                                    }
                                    color: root.theme.textPrimary
                                    font.pixelSize: panel.scale_per_monitor(16)
                                    font.family: root.font

                                    opacity: mouseVolume.containsMouse ? 1.0 : 0.0
                                    visible: opacity > 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: mouseVolume
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (sink && sink.audio)
                                        sink.audio.muted = !sink.audio.muted;
                                }
                                onWheel: wheel => {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (!sink || !sink.audio)
                                        return;
                                    const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                    sink.audio.volume = Math.max(0, Math.min(1.2, sink.audio.volume + delta));
                                }
                            }
                        }

                        // Brightness
                        Rectangle {
                            height: 24
                            width: brightContent.width + 12
                            radius: 8
                            color: root.theme.bgSurface
                            visible: brightnessFile.path !== ""

                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Brightness: " + Math.round(root.brightnessValue * 100) + "%"
                            Behavior on width {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutExpo
                                }
                            }

                            Row {
                                id: brightContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰃠"
                                    color: root.theme.accentOrange
                                    font.pixelSize: panel.scale_per_monitor(18)
                                    font.family: root.font
                                }

                                Text {
                                    id: brightnessPercentText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Math.round(root.brightnessValue * 100) + "%"
                                    color: root.theme.textPrimary

                                    font.pixelSize: panel.scale_per_monitor(16)
                                    font.family: root.font

                                    opacity: mouseBrightness.containsMouse ? 1.0 : 0.0
                                    visible: opacity > 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: mouseBrightness
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onWheel: wheel => {
                                    brightnessSetProc.command = wheel.angleDelta.y > 0 ? ["brightnessctl", "set", "5%+"] : ["brightnessctl", "set", "5%-"];
                                    brightnessSetProc.running = true;
                                }
                            }
                        }

                        // Network
                        Rectangle {
                            height: 24
                            width: netContent.width + 12
                            radius: 8
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: {
                                if (SystemInfo.networkType === "ethernet")
                                    return "Network: Ethernet";
                                if (SystemInfo.networkType === "wifi")
                                    return "Network: WiFi " + SystemInfo.networkInfo;
                                return "Network: Disconnected";
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutExpo
                                }
                            }

                            Row {
                                id: netContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (SystemInfo.networkType === "ethernet")
                                            return "󰈀";
                                        if (SystemInfo.networkType === "wifi")
                                            return "󰖩";
                                        return "󰖪";
                                    }
                                    color: SystemInfo.networkType === "disconnected" ? root.theme.textMuted : root.theme.accentGreen
                                    font.pixelSize: panel.scale_per_monitor(18)
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    //text: mouseNetwork.containsMouse ? SystemInfo.networkInfo : SystemInfo.networkInfo.slice(0, 3) + ".."
                                    text: SystemInfo.networkInfo
                                    color: root.theme.textPrimary
                                    clip: true
                                    font.pixelSize: panel.scale_per_monitor(14)
                                    font.family: root.font
                                    width: (implicitWidth < panel.scale_per_monitor(30) || mouseNetwork.containsMouse) ? implicitWidth : panel.scale_per_monitor(30)
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: mouseNetwork
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                            }
                        }

                        // Battery
                        Rectangle {
                            height: 24
                            width: battContent.width + 12
                            radius: 8
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Battery: " + SystemInfo.batteryLevel
                            Behavior on width {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutExpo
                                }
                            }

                            Row {
                                id: battContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.batteryIcon
                                    color: sysInfo.batteryColor
                                    font.pixelSize: panel.scale_per_monitor(25)
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.batteryLevel
                                    color: root.theme.textPrimary
                                    font.pixelSize: panel.scale_per_monitor(18)
                                    font.family: root.font
                                    opacity: mouseBatt.containsMouse ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: mouseBatt
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }
    }
}
