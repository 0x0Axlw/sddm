/**
 * Pixie SDDM
 * A minimal SDDM theme inspired by Pixel UI and Material Design 3.
 * Author: xCaptaiN09
 * GitHub: https://github.com/xCaptaiN09/pixie-sddm
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "components"

Rectangle {
    id: container
    width: 1920
    height: 1080
    color: baseColor
    focus: !loginState.visible

    // User & Session Logic (Root Level)
    property int userIndex: 0
    property int sessionIndex: 0
    property bool isLoggingIn: false

    Component.onCompleted: {
        if (typeof userModel !== "undefined" && userModel.lastIndex >= 0) userIndex = userModel.lastIndex;
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) sessionIndex = sessionModel.lastIndex;
        updateUserAvatar();
    }

    function cleanName(name) {
        if (!name) return "";
        var s = name.toString();
        if (s.endsWith("/")) s = s.substring(0, s.length - 1);
        if (s.indexOf("/") !== -1) s = s.substring(s.lastIndexOf("/") + 1);
        if (s.indexOf(".desktop") !== -1) s = s.substring(0, s.indexOf(".desktop"));
        s = s.replace(/[-_]/g, ' ');
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // The login username: SDDM's userModel EditRole is the account login name
    // (UserRole+1 NameRole is the same; DisplayRole is the display name and
    // must never be submitted). Falls back to SDDM's last logged-in user.
    function selectedLoginName() {
        if (typeof userModel !== "undefined" && userModel.count > 0) {
            var idx = Math.max(0, Math.min(container.userIndex, userModel.count - 1));
            var mIdx = userModel.index(idx, 0);
            var edit = userModel.data(mIdx, Qt.EditRole);
            var nameRole = userModel.data(mIdx, Qt.UserRole + 1);
            return (edit ? edit.toString() : (nameRole ? nameRole.toString() : ""));
        }
        return (sddm && sddm.lastUser && sddm.lastUser.length > 0) ? sddm.lastUser.toString() : "";
    }

    // Clamp helper so popups/dropdowns and the submit path agree.
    function validSessionIndex() {
        var sess = container.sessionIndex;
        if (typeof sessionModel !== "undefined" && sessionModel.count > 0) {
            if (sess < 0 || sess >= sessionModel.count) sess = 0;
        } else {
            sess = 0; // model missing or empty: submit the default session
        }
        return sess;
    }

    function doLogin() {
        if (!loginState.visible || container.isLoggingIn) return;

        var user = selectedLoginName();
        // No usable identity (no users and no lastUser) - never guess.
        if (!user || user.length === 0) {
            console.log("Pixie SDDM: no valid user available; suppressing login.");
            return;
        }

        var pass = passwordField.text;
        if (!pass || pass.length === 0) {
            // Clear feedback instead of a doomed SDDM round-trip.
            loginState.showErrorHint("Please enter your password");
            return;
        }

        container.isLoggingIn = true;
        var sess = validSessionIndex();

        console.log("Pixie SDDM: Attempting login for the selected user, session index [" + sess + "]");
        sddm.login(user, pass, sess);
        loginTimeout.start();
    }

    Timer {
        id: loginTimeout
        interval: 5000
        onTriggered: container.isLoggingIn = false
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            container.isLoggingIn = false
            loginTimeout.stop()
            loginState.showErrorHint("Incorrect password. Try again.")
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
        function onLoginSucceeded() {
            loginTimeout.stop()
        }
    }

    // Keep the avatar in sync with the selected user. Priority:
    //   1. per-user avatar      (scripts/change-avatar.sh -> theme.conf
    //                            "avatar_<username>" key -> shared assets dir)
    //   2. SDDM's per-user icon (UserRole+3 IconRole, usually ~/.face)
    //   3. the bundled default  (assets/avatar.jpg)
    // config is a dynamic property map in the greeter, so unknown keys are
    // safe: a missing entry reads as undefined here.
    function selectedUserAvatarKey(name) {
        return (name === "") ? "" : ("avatar_" + name);
    }

    // Selected user's login name (UserRole+1 = EditRole); "" when unknown.
    function selectedUserName() {
        if (typeof userModel !== "undefined" && userModel.count > 0) {
            var idx = Math.max(0, Math.min(container.userIndex, userModel.count - 1));
            var name = userModel.data(userModel.index(idx, 0), Qt.UserRole + 1);
            if (name) return name.toString();
            var disp = userModel.data(userModel.index(idx, 0), Qt.DisplayRole);
            if (disp) return disp.toString();
        }
        if (typeof sddm !== "undefined" && sddm.lastUser) return sddm.lastUser.toString();
        return "";
    }

    function selectedUserIcon() {
        var name = selectedUserName();
        if (name !== "") {
            var key = "avatar_" + name;
            var own = config[key];
            if (own && own.toString().length > 0) return own.toString();
        }
        if (typeof userModel !== "undefined" && userModel.count > 0) {
            var idx = Math.max(0, Math.min(container.userIndex, userModel.count - 1));
            var icon = userModel.data(userModel.index(idx, 0), Qt.UserRole + 3);
            if (icon && /\.(jpg|jpeg|png|bmp|webp|svg)$/i.test(icon.toString())) {
                return icon.toString();
            }
        }
        return "assets/avatar.jpg";
    }

    function updateUserAvatar() {
        var s = selectedUserIcon();
        if (avatar.source.toString() !== Qt.resolvedUrl(s).toString()) {
            avatar.source = s;
            avatarCanvas.requestPaint();
        } else {
            avatarCanvas.requestPaint();
        }
    }

    onUserIndexChanged: updateUserAvatar()

    // Wallpaper & palette resolution:
    //   1. "wallpaper" key  - synced desktop wallpaper (scripts/update-wallpaper.sh)
    //   2. "background" key - bundled default / manual configuration
    // Fallback: if loading the synced wallpaper fails (deleted, unreadable),
    // it falls back to the bundled default instead of showing a blank screen.
    property string wallpaperKey: (config.wallpaper && config.wallpaper.length > 0) ? config.wallpaper : config.background

    Image {
        id: backgroundImage
        property bool fallbackActive: false
        source: container.wallpaperKey
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop

        onStatusChanged: {
            if (status === Image.Error && !fallbackActive) {
                fallbackActive = true;
                console.log("Pixie SDDM: Background failed to load (" + source + "), using built-in default.");
                source = "assets/background.jpg";
            }
        }
    }

    // Palette priority: Matugen palette > static colors > runtime autoColor extraction.
    property bool matugenActive: config.matugen === "true" && config.matugenAccent && config.matugenAccent.length > 0
    property color extractedAccent: matugenActive ? config.matugenAccent : config.accentColor
    property color baseColor: matugenActive ? (config.matugenBackground && config.matugenBackground.length > 0 ? config.matugenBackground : config.backgroundColor) : config.backgroundColor
    property color textColor: matugenActive ? (config.matugenText && config.matugenText.length > 0 ? config.matugenText : config.textColor) : config.textColor
    property color surfaceColor: Qt.lighter(baseColor, 1.3)
    property color surfaceVariantColor: Qt.lighter(baseColor, 1.6)
    // Contrast-based roles for M3 widgets on top of the active palette.
    function lumaOf(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b; }
    property color onAccentColor: lumaOf(extractedAccent) > 0.6 ? "#101418" : "#FFFFFF"
    property color accentHoverColor: Qt.lighter(extractedAccent, 1.08)
    property color accentPressedColor: Qt.darker(extractedAccent, 1.15)
    property bool uiReady: matugenActive || config.autoColor !== "true" || colorExtractor.processed

    Timer {
        id: colorDelay
        interval: 1000 // Give it a full second
        repeat: true   // Keep trying until we succeed
        // The extractor only runs when NO Matugen palette is active;
        // otherwise it would overwrite the Matugen-driven color bindings.
        running: backgroundImage.status === Image.Ready && !colorExtractor.processed && config.autoColor === "true" && !container.matugenActive
        onTriggered: colorExtractor.requestPaint()
    }

    Canvas {
        id: colorExtractor
        width: 60; height: 60
        x: -100; y: -100 // Off-screen but "visible" for reliable rendering
        z: -1
        renderTarget: Canvas.Image
        property bool processed: false
        property int retries: 0 // Add this to track GPU sync delays

        onPaint: {
            // Never fight the Matugen palette: skip extraction entirely when active.
            if (container.matugenActive) { processed = true; return; }
            var ctx = getContext("2d");
            var res = 60;
            ctx.clearRect(0, 0, res, res);
            ctx.drawImage(backgroundImage, 0, 0, res, res);
            var imgData = ctx.getImageData(0, 0, res, res).data;

            if (!imgData || imgData.length === 0) return;

            // 36 Buckets (10 degrees each) for high resolution hue detection
            var histogram = new Array(36).fill(0);
            var sampleColors = new Array(36).fill(null);
            var vibrantFound = false;

            // FIX: Check if canvas read pure black (GPU sync delay bug)
            var pixelSum = 0;
            for (var p = 0; p < imgData.length; p++) pixelSum += imgData[p];

            if (pixelSum === 0) {
                retries++;
                if (retries > 3) {
                    // If it's still pure black after 3 tries, it's a true black wallpaper
                    container.extractedAccent = "#D0D0D0";
                    console.log("Pixie SDDM: Pure black wallpaper detected. Using neutral contrast.");
                    processed = true;
                }
                return; // Keep trying if it's just a GPU delay
            }

            // Reset retries if we got pixels
            retries = 0;

            for (var i = 0; i < imgData.length; i += 4) {
                var r = imgData[i] / 255;
                var g = imgData[i+1] / 255;
                var b = imgData[i+2] / 255;
                var pCol = Qt.rgba(r, g, b, 1.0);

                // Filter: Must be colorful and not too dark
                if (pCol.hsvSaturation > 0.3 && pCol.hsvValue > 0.15) {
                    var h = pCol.hsvHue * 360;
                    if (h < 0) continue;

                    var bIdx = Math.floor(h / 10) % 36;
                    var weight = pCol.hsvSaturation * pCol.hsvValue;
                    histogram[bIdx] += weight;

                    if (!sampleColors[bIdx] || weight > (sampleColors[bIdx].hsvSaturation * sampleColors[bIdx].hsvValue)) {
                        sampleColors[bIdx] = pCol;
                    }
                    vibrantFound = true;
                }
            }

            if (!vibrantFound) {
                // Calculate average brightness for monochrome wallpapers (greys/whites)
                var totalBrightness = 0;
                var pixelCount = imgData.length / 4;
                for (var k = 0; k < imgData.length; k += 4) {
                    var r_l = imgData[k] / 255;
                    var g_l = imgData[k+1] / 255;
                    var b_l = imgData[k+2] / 255;
                    totalBrightness += (0.299 * r_l + 0.587 * g_l + 0.114 * b_l);
                }
                var avgBrightness = totalBrightness / pixelCount;

                container.extractedAccent = avgBrightness < 0.5 ? "#D0D0D0" : "#404040";
                console.log("Pixie SDDM: No vibrant colors. Avg brightness: " + avgBrightness.toFixed(2) + ". Using neutral contrast.");
                processed = true;
                return;
            }

            // Merge Red wrap (350-360 and 0-10)
            histogram[0] += histogram[35];

            // Find the most frequent vibrant hue (The Mode)
            var maxCount = -1;
            var winnerIdx = -1;
            for (var j = 0; j < 35; j++) {
                if (histogram[j] > maxCount) {
                    maxCount = histogram[j];
                    winnerIdx = j;
                }
            }

            if (winnerIdx !== -1 && sampleColors[winnerIdx]) {
                var finalColor = sampleColors[winnerIdx];
                var h = finalColor.hsvHue;
                var s = Math.max(0.35, Math.min(0.55, finalColor.hsvSaturation * 0.9));
                container.extractedAccent = Qt.hsva(h, s, 0.95, 1.0);
                console.log("Pixie SDDM: SUCCESS! Extracted Hue: " + (h * 360).toFixed(0) + "°");
                processed = true;
            }
        }
    }

    Connections {
        target: backgroundImage
        function onStatusChanged() {
            if (backgroundImage.status === Image.Ready && !container.matugenActive) {
                colorExtractor.processed = false;
                colorDelay.start();
            }
        }
    }

    FontLoader { id: fontRegular; source: "assets/fonts/FlexRounded-R.ttf" }
    FontLoader { id: fontMedium; source: "assets/fonts/FlexRounded-M.ttf" }
    FontLoader { id: fontBold; source: "assets/fonts/FlexRounded-B.ttf" }

    property var availableFonts: Qt.fontFamilies()
    property string activeFontRegular: (config.fontFamily && config.fontFamily.length > 0 && availableFonts.indexOf(config.fontFamily) >= 0) ? config.fontFamily : fontRegular.name
    property string activeFontBold:    (config.fontFamily && config.fontFamily.length > 0 && availableFonts.indexOf(config.fontFamily) >= 0) ? config.fontFamily : fontBold.name

    // High-Quality Standalone Blur (Qt6 Native)
    MultiEffect {
        id: backgroundBlur
        anchors.fill: parent
        source: backgroundImage
        blurEnabled: true
        blur: loginState.visible ? 1.0 : 0.0
        opacity: loginState.visible ? 1.0 : 0.0
        autoPaddingEnabled: false

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
        Behavior on blur { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
        Behavior on opacity { NumberAnimation { duration: m3.durationLarge } }
    }

    PowerBar {
        // Bottom-right corner, responsive margins (no fixed screen offsets,
        // clears the centered hint by design and scales on short screens).
        anchors {
            bottom: parent.bottom
            right: parent.right
            bottomMargin: Math.max(m3.barMinEdge, Math.min(parent.width, parent.height) * m3.barEdgeFactor)
            rightMargin: Math.max(m3.barMinEdge, Math.min(parent.width, parent.height) * m3.barEdgeFactor)
        }
        textColor: container.textColor
        z: 100
        opacity: container.uiReady ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Shortcut {
        sequence: "Escape"
        // Modal popups handle Escape themselves (CloseOnEscape).
        enabled: loginState.visible && !userPopup.opened && !sessionPopup.opened
        onActivated: {
            loginState.visible = false;
            loginState.isError = false;
            passwordField.text = "";
            container.focus = true;
        }
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        // No submission while a modal popup has the interaction; the popup's
        // own Return/Enter handlers just pick the row and close.
        enabled: loginState.visible && !userPopup.opened && !sessionPopup.opened
        onActivated: container.doLogin()
    }

    // Design tokens (materials from the end-4 style shell, see components/M3.qml)
    M3 { id: m3 }

    // Softened text for secondary composition (mix toward the background).
    function mixColors(c1, c2, t) {
        return Qt.rgba(c1.r + (c2.r - c1.r) * t,
                       c1.g + (c2.g - c1.g) * t,
                       c1.b + (c2.b - c1.b) * t,
                       c1.a);
    }

    Item {
        id: lockState
        anchors.fill: parent
        visible: !loginState.visible
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: m3.durationLarge } }

        // Horizontal Pixel-style clock above center with its date below.
        Clock {
            id: mainClock
            anchors.fill: parent
            baseAccent: container.extractedAccent
            fontFamily: container.activeFontRegular
            dateText: Qt.locale().toString(mainClock.now, (config.dateFormat && config.dateFormat.length > 0) ? config.dateFormat : "dddd, MMMM d")
            dateColor: mixColors(container.textColor, container.baseColor, 0.3)
            opacity: container.uiReady ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: m3.durationNormal } }
        }

        Text {
            text: "Press any key to unlock"
            color: container.textColor
            font.pixelSize: m3.typeNormal
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 100
            }
            opacity: 0.5
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                loginState.visible = true;
                passwordField.forceActiveFocus();
            }
        }
    }

    Item {
        id: loginState
        objectName: "loginState"        // harness/test hook
        anchors.fill: parent
        visible: false
        opacity: visible ? 1 : 0
        z: 10
        Behavior on opacity { NumberAnimation { duration: 400 } }

        onVisibleChanged: {
            if (visible) passwordField.forceActiveFocus();
        }

        property bool isError: false
        // M3 supporting text under the field; empty when not in an error.
        property string errorHint: ""
        function showErrorHint(msg) {
            errorHint = msg;
            isError = true;
            shakeAnimation.start();
        }

        SequentialAnimation {
            id: shakeAnimation
            loops: 2
            // Shake the floating login composition (anchor-offset shake keeps
            // the center binding intact).
            PropertyAnimation { target: loginFloat; property: "anchors.horizontalCenterOffset"; from: 0; to: -10; duration: 50; easing.type: Easing.InOutQuad }
            PropertyAnimation { target: loginFloat; property: "anchors.horizontalCenterOffset"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
            PropertyAnimation { target: loginFloat; property: "anchors.horizontalCenterOffset"; from: 10; to: 0; duration: 50; easing.type: Easing.InOutQuad }
            onStopped: {
                loginState.isError = false;
                loginState.errorHint = "";
            }
        }

        // Floating login composition: no giant card. The wallpaper is already
        // blurred by backgroundBlur; controls sit directly on it, M3-style.
        ColumnLayout {
            id: loginFloat
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            spacing: m3.spaceL

                Item {
                    // Avatar scales with the screen, clamped for tiny/huge displays.
                    readonly property real diameter: Math.max(m3.avatarMinSize, Math.min(m3.avatarMaxSize, container.width * m3.avatarScreenFactor))
                    Layout.preferredWidth: diameter
                    Layout.preferredHeight: diameter
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        id: avatarFallback
                        anchors.fill: parent
                        color: surfaceColor
                        radius: width / 2
                        visible: avatar.status !== Image.Ready

                        Text {
                            anchors.centerIn: parent
                            text: {
                                var n = "";
                                if (typeof userModel !== "undefined" && userModel.count > 0) {
                                    var d = userModel.data(userModel.index(container.userIndex, 0), Qt.DisplayRole);
                                    var nr = userModel.data(userModel.index(container.userIndex, 0), Qt.UserRole + 1);
                                    n = d ? d.toString() : (nr ? nr.toString() : "U");
                                } else {
                                    n = sddm.lastUser ? sddm.lastUser : "U";
                                }
                                return n.charAt(0).toUpperCase();
                            }
                            color: container.extractedAccent
                            font.pixelSize: 48
                            font.family: activeFontBold
                            font.weight: Font.Bold
                        }
                    }

                    // Bulletproof Circular Avatar (Canvas method)
                    // Aspect-fill center crop (no distortion for non-square
                    // icons) with a subtle edge-trim zoom so images with airy
                    // content borders still fill the circle edge-to-edge.
                    Canvas {
                        id: avatarCanvas
                        anchors.fill: parent
                        visible: avatar.status === Image.Ready

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        onPaint: {
                            if (avatar.status !== Image.Ready) return;
                            var ctx = getContext("2d");
                            ctx.reset();
                            var iw = avatar.implicitWidth;
                            var ih = avatar.implicitHeight;
                            if (iw <= 0 || ih <= 0) { iw = width; ih = height; }
                            // Center-crop a square region of the source
                            var side = Math.min(iw, ih);
                            var sx = (iw - side) / 2;
                            var sy = (ih - side) / 2;
                            var sw = side;
                            var sh = side;
                            // Edge trim: shrink the source rect toward the center
                            var zoom = m3.avatarEdgeTrim;
                            var inset = side * (1 - 1 / zoom) / 2;
                            sx += inset;
                            sy += inset;
                            sw -= inset * 2;
                            sh -= inset * 2;
                            ctx.beginPath();
                            ctx.arc(width/2, height/2, width/2, 0, 2 * Math.PI);
                            ctx.closePath();
                            ctx.clip();
                            ctx.drawImage(avatar, sx, sy, sw, sh, 0, 0, width, height);
                        }

                        Timer {
                            id: repaintTimer
                            interval: 500
                            onTriggered: avatarCanvas.requestPaint()
                        }

                        Image {
                            id: avatar
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            visible: false

                            Component.onCompleted: {
                                source = Qt.resolvedUrl(selectedUserIcon());
                            }

                            onStatusChanged: {
                                if (status === Image.Ready) {
                                    console.log("Pixie SDDM: Image ready, repainting Canvas.");
                                    repaintTimer.start();
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: userNameLabel.width + m3.spaceXXL
                    Layout.preferredHeight: userNameLabel.height + m3.spaceL
                    Layout.topMargin: m3.spaceXS

                    Rectangle {
                        anchors.fill: parent
                        color: "white"
                        opacity: userClickArea.pressed ? 0.2 : 0
                        radius: m3.radiusSmall
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    Text {
                        id: userNameLabel
                        anchors.centerIn: parent
                        text: {
                            if (typeof userModel !== "undefined" && userModel.count > 0) {
                                var idx = container.userIndex;
                                var modelIdx = userModel.index(idx, 0);
                                var display = userModel.data(modelIdx, Qt.DisplayRole);
                                var edit = userModel.data(modelIdx, Qt.EditRole);
                                var nr = userModel.data(modelIdx, Qt.UserRole + 1);
                                var realName = userModel.data(modelIdx, Qt.UserRole + 2);
                                var finalName = display ? display.toString() : (realName ? realName.toString() : (nr ? nr.toString() : (edit ? edit.toString() : "User")));
                                return cleanName(finalName) + (userModel.count > 1 ? " ▾" : "");
                            }
                            return cleanName(sddm.lastUser ? sddm.lastUser : "User");
                        }
                        color: container.textColor
                        font.pixelSize: m3.typeTitle
                        font.weight: Font.Bold
                        font.family: activeFontRegular
                    }

                    MouseArea {
                        id: userClickArea
                        anchors.fill: parent
                        // Useless for single-user systems - only multi-user
                        // sessions get a selector.
                        enabled: typeof userModel !== "undefined" && userModel.count > 1
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: userPopup.open()
                    }

                    scale: userClickArea.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                Rectangle {
                    id: sessionPill
                    visible: typeof sessionModel !== "undefined" && sessionModel.count > 1
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: m3.controlPillWidth + m3.spaceXL
                    Layout.preferredHeight: m3.controlPillHeight
                    color: (sessionClickArea.pressed || sessionPopup.opened) ? surfaceVariantColor : surfaceColor
                    radius: m3.radiusNormal
                    border.width: 1
                    border.color: (sessionClickArea.pressed || sessionPopup.opened) ? container.extractedAccent : surfaceVariantColor

                    scale: sessionClickArea.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "󰟀"
                            color: container.extractedAccent
                            font.pixelSize: m3.typeNormal
                        }
                        Text {
                            text: {
                                if (typeof sessionModel !== "undefined" && sessionModel.count > 0) {
                                    var idx = container.sessionIndex;
                                    var modelIdx = sessionModel.index(idx, 0);
                                    var n = sessionModel.data(modelIdx, Qt.UserRole + 4);
                                    var f = sessionModel.data(modelIdx, Qt.UserRole + 2);
                                    var d = sessionModel.data(modelIdx, Qt.DisplayRole);
                                    var finalName = n ? n.toString() : (f ? f.toString() : (d ? d.toString() : "Session " + (idx + 1)));
                                    return cleanName(finalName) + (sessionModel.count > 1 ? " ▾" : "");
                                }
                                return "Hyprland";
                            }
                            color: container.textColor
                            font.pixelSize: m3.typeSmaller + 1
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: sessionClickArea
                        anchors.fill: parent
                        onClicked: sessionPopup.open()
                    }
                }

                TextField {
                    id: passwordField
                    objectName: "passwordField"     // harness/test hook
                    Layout.topMargin: m3.spaceXL // Keeps space above it static
                    // Responsive width, clamped - never full-bleed, never cramped.
                    Layout.preferredWidth: Math.max(m3.typeNormal * 20, Math.min(420, container.width * 0.22))
                    Layout.preferredHeight: Math.max(m3.fieldMinHeight, m3.typeLarger + m3.fieldBlockPadding * 2)
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: m3.typeLarger
                    font.family: container.activeFontRegular
                    color: container.textColor
                    selectionColor: container.extractedAccent
                    focus: loginState.visible
                    enabled: !container.isLoggingIn

                    background: Rectangle {
                        // Translucent filled M3 field over the blurred wallpaper.
                        color: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.6)
                        radius: passwordField.height / 2
                        // Constant width: focus/error changes re-color only, so
                        // the field never resizes or shifts.
                        border.width: m3.fieldBorderWidth
                        border.color: {
                            if (loginState.isError) return m3.errorColor;
                            if (passwordField.activeFocus) return container.extractedAccent;
                            return container.mixColors(surfaceVariantColor, container.baseColor, 0.2);
                        }
                        opacity: passwordField.enabled ? 1.0 : 0.5
                        Behavior on border.color { ColorAnimation { duration: m3.durationFast } }
                    }

                    // Custom placeholder: deterministic rendering (the native
                    // placeholderText fights Qt6 internals with custom fonts),
                    // colored as the M3 "onSurface ~38%" supporting role.
                    Text {
                        text: "Password"
                        color: container.mixColors(container.textColor, container.baseColor, 0.45)
                        font.pixelSize: m3.typeNormal
                        font.family: container.activeFontRegular
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !passwordField.text && !loginState.isError
                    }

                    // Clear the error as soon as the user starts retyping.
                    onTextEdited: if (loginState.isError) { loginState.isError = false; loginState.errorHint = ""; }

                    onAccepted: container.doLogin()
                }

                Text {
                    id: fieldErrorHint
                    // Reserved slot height: the composition never shifts when
                    // the error state appears or disappears.
                    Layout.preferredWidth: passwordField.width
                    Layout.preferredHeight: m3.typeSmaller * 1.6
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 0
                    text: loginState.errorHint
                    visible: loginState.isError
                    color: m3.errorColor
                    font.pixelSize: m3.typeSmaller
                    font.family: container.activeFontRegular
                    horizontalAlignment: Text.AlignHCenter
                    opacity: loginState.isError ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: m3.durationFast } }
                }

                Text {
                    id: numLockIndicator
                    text: "Num Lock is on"
                    color: container.extractedAccent
                    font.pixelSize: m3.typeSmall
                    font.family: activeFontRegular
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignHCenter
                    visible: {
                        if (typeof keyboard !== "undefined" && typeof keyboard.numLock !== "undefined") return keyboard.numLock;
                        return false;
                    }
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: m3.durationNormal } }
                }

                // M3 FAB with a restrained elevation shadow (MultiEffect).
                Item {
                    readonly property real fabSize: m3.controlFabSize
                    Layout.preferredWidth: fabSize
                    Layout.preferredHeight: fabSize
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: m3.spaceS

                    MultiEffect {
                        anchors.fill: parent
                        anchors.margins: -m3.spaceM
                        source: loginButton
                        shadowEnabled: true
                        shadowColor: "#33000000"
                        shadowVerticalOffset: 2.0
                        autoPaddingEnabled: false
                        shadowBlur: 0.35
                    }

                    RoundButton {
                        id: loginButton
                        anchors.fill: parent
                        hoverEnabled: true
                        focusPolicy: Qt.NoFocus
                        enabled: !container.isLoggingIn

                    contentItem: Text {
                        text: container.isLoggingIn ? "⋯" : "→"
                        // Accessible contrast against the Matugen accent fill.
                        color: container.onAccentColor
                        font.pixelSize: m3.controlFabSize * 0.42
                        font.family: container.activeFontBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        // Material 3 filled FAB: the Matugen accent, never hardcoded.
                        color: {
                            if (container.isLoggingIn) return surfaceVariantColor;
                            if (loginButton.pressed) return container.accentPressedColor;
                            if (loginButton.hovered) return container.accentHoverColor;
                            return container.extractedAccent;
                        }
                        radius: width / 2
                        opacity: container.isLoggingIn ? 0.5 : 1.0
                        Behavior on color { ColorAnimation { duration: m3.durationFast } }
                        scale: loginButton.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: m3.durationFast; easing.type: Easing.OutQuad } }
                    }

                    onClicked: {
                        container.doLogin();
                    }

                    // Keyboard path is Enter (global shortcuts); still expose
                    // the action to accessibility frameworks.
                    Accessible.role: Accessible.Button
                    Accessible.name: "Log in"
                    Accessible.onPressAction: container.doLogin()
                }
            }
        }
    }

    Keys.onPressed: function(event) {
        if (!loginState.visible) {
            loginState.visible = true;
            passwordField.forceActiveFocus();
            event.accepted = true;
        }
    }

    Popup {
        id: userPopup
        width: m3.popupWidth
        height: (typeof userModel !== "undefined") ? Math.min(300, userModel.count * 50 + 20) : 100
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 - 50
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: userList.forceActiveFocus()
        background: Rectangle {
            color: baseColor
            radius: m3.radiusLarge
            opacity: 0.95
            border.color: surfaceVariantColor
            border.width: 1
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: m3.durationNormal } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: m3.durationNormal } }
        ListView {
            id: userList
            anchors.fill: parent
            anchors.margins: 10
            model: (typeof userModel !== "undefined") ? userModel : null
            spacing: 5
            clip: true
            focus: true
            currentIndex: container.userIndex
            highlightFollowsCurrentItem: true
            delegate: ItemDelegate {
                width: parent.width
                height: 40
                property bool isCurrent: index === userList.currentIndex
                background: Rectangle {
                    color: isCurrent ? surfaceVariantColor : (hovered ? surfaceColor : "transparent")
                    radius: m3.radiusSmall
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        width: 4
                        height: isCurrent ? 16 : 0
                        color: container.extractedAccent
                        radius: 2
                        Behavior on height { NumberAnimation { duration: m3.durationFast } }
                    }
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredWidth: 20 }
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        color: isCurrent ? container.extractedAccent : surfaceVariantColor
                        radius: 14
                        Text {
                            anchors.centerIn: parent
                            text: {
                                var mIdx = userModel.index(index, 0);
                                var d = userModel.data(mIdx, Qt.DisplayRole);
                                var n_r = userModel.data(mIdx, Qt.UserRole + 1);
                                var finalVal = d ? d.toString() : (n_r ? n_r.toString() : "U");
                                return finalVal.charAt(0).toUpperCase();
                            }
                            color: isCurrent ? baseColor : container.textColor
                            font.pixelSize: m3.typeSmaller
                            font.family: activeFontBold
                            font.weight: Font.Bold
                        }
                    }
                    Item { Layout.preferredWidth: 12 }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            var mIdx = userModel.index(index, 0);
                            var d = userModel.data(mIdx, Qt.DisplayRole);
                            var n_r = userModel.data(mIdx, Qt.UserRole + 1);
                            var r = userModel.data(mIdx, Qt.UserRole + 2);
                            var e = userModel.data(mIdx, Qt.EditRole);
                            return cleanName(d ? d : (r ? r : (n_r ? n_r : e)));
                        }
                        color: isCurrent ? container.textColor : (hovered ? "#DDDDDD" : "#AAAAAA")
                        font.pixelSize: m3.typeSmall
                        font.family: activeFontRegular
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 60
                        elide: Text.ElideRight
                    }
                }
                onClicked: {
                    container.userIndex = index;
                    userPopup.close();
                }
            }
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onReturnPressed: { container.userIndex = currentIndex; userPopup.close(); }
            Keys.onEnterPressed: { container.userIndex = currentIndex; userPopup.close(); }
        }
    }

    Popup {
        id: sessionPopup
        width: m3.popupWidth
        height: (typeof sessionModel !== "undefined") ? Math.min(250, sessionModel.count * 50 + 20) : 100
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 + 80
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: sessionList.forceActiveFocus()
        background: Rectangle {
            color: baseColor
            radius: m3.radiusLarge
            opacity: 0.95
            border.color: surfaceVariantColor
            border.width: 1
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: m3.durationNormal } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: m3.durationNormal } }
        ListView {
            id: sessionList
            anchors.fill: parent
            anchors.margins: 10
            model: (typeof sessionModel !== "undefined") ? sessionModel : null
            spacing: 5
            clip: true
            focus: true
            currentIndex: container.sessionIndex
            highlightFollowsCurrentItem: true
            delegate: ItemDelegate {
                width: parent.width
                height: 40
                property bool isCurrent: index === sessionList.currentIndex
                background: Rectangle {
                    color: isCurrent ? surfaceVariantColor : (hovered ? surfaceColor : "transparent")
                    radius: m3.radiusSmall
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        width: 4
                        height: isCurrent ? 16 : 0
                        color: container.extractedAccent
                        radius: 2
                        Behavior on height { NumberAnimation { duration: m3.durationFast } }
                    }
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredWidth: 20 }
                    Text {
                        Layout.preferredWidth: 40
                        text: "󰟀"
                        color: isCurrent ? container.extractedAccent : "gray"
                        font.pixelSize: m3.typeNormal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            var n_val = sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 4);
                            var f_val = sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 2);
                            return cleanName(n_val ? n_val : f_val);
                        }
                        color: isCurrent ? container.textColor : "#AAAAAA"
                        font.pixelSize: m3.typeSmall
                        font.family: activeFontRegular
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 60
                        elide: Text.ElideRight
                    }
                }
                onClicked: {
                    container.sessionIndex = index;
                    sessionPopup.close();
                }
            }
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onReturnPressed: { container.sessionIndex = currentIndex; sessionPopup.close(); }
            Keys.onEnterPressed: { container.sessionIndex = currentIndex; sessionPopup.close(); }
        }
    }
}
