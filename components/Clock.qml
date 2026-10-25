/**
 * Pixie SDDM - Clock Component
 * Horizontal Pixel-style clock: a single cohesive time line (bold hours +
 * soft minutes, M3 two-tone treatment), round colon dots and the date line
 * below, following the Material 3 design language.
 *
 * Fully responsive: the display size is derived from the available space
 * (height- and width-fit, clamped) - no fixed font sizes or coordinates.
 *
 * Author: xCaptaiN09
 */
import QtQuick

Item {
    id: clock

    // ---- API (injected by Main.qml; defaults keep previews sane) ----
    property string dateText: ""
    property color dateColor: "#FFFFFF"
    property string fontFamily: "FlexRounded"
    property color baseAccent: config.accentColor
    property color defaultHoursColor: "#AED68A"
    property color defaultMinutesColor: "#D4E4BC"

    // Two-tone colors (wallpaper-responsive)
    property color smartHoursColor: defaultHoursColor
    property color smartMinutesColor: defaultMinutesColor

    // ---- Time state ----
    property var now: new Date()
    property string hoursStr: ""
    property string minutesStr: ""

    M3 { id: m3 }

    // Display size fits both the available height and width, clamped.
    readonly property real displaySize: {
        var byHeight = height * m3.clockHeightFactor;
        var byWidth = width * m3.clockWidthFactor;
        return Math.min(m3.clockMaxSize, Math.max(m3.clockMinSize, Math.min(byHeight, byWidth)));
    }

    function updateTime() {
        var date = new Date();
        clock.now = date;
        var hours = date.getHours();
        // If 24-hour is not strictly "true", convert to 12-hour format
        if (config.use24HourClock !== "true") {
            hours = hours % 12;
            if (hours === 0) hours = 12; // Midnight becomes 12
            clock.hoursStr = "" + hours; // No zero padding in 12-hour mode
        } else {
            clock.hoursStr = hours < 10 ? "0" + hours : "" + hours;
        }
        var minutes = date.getMinutes();
        clock.minutesStr = minutes < 10 ? "0" + minutes : "" + minutes;
    }

    function updateColors() {
        var base = clock.baseAccent;

        if (base.hsvSaturation < 0.15) {
            clock.smartHoursColor = Qt.lighter(base, 1.3);
            clock.smartMinutesColor = Qt.darker(base, 1.4);
            return;
        }

        if (base.hsvValue < 0.5) {
            clock.smartHoursColor = Qt.hsva(base.hsvHue, 0.7, 0.9, 1.0);
            clock.smartMinutesColor = Qt.hsva(base.hsvHue, 0.45, 0.85, 1.0);
        } else if (base.hsvValue > 0.8 && base.hsvSaturation < 0.2) {
            clock.smartHoursColor = Qt.hsva(base.hsvHue, 0.8, 0.7, 1.0);
            clock.smartMinutesColor = Qt.hsva(base.hsvHue, 0.5, 0.75, 1.0);
        } else {
            clock.smartHoursColor = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 1.3), 0.95, 1.0);
            clock.smartMinutesColor = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 0.75), 0.92, 1.0);
        }
    }

    onBaseAccentChanged: updateColors()
    Component.onCompleted: {
        updateColors();
        updateTime();
    }

    // ---- Composition ----
    Column {
        id: contentLayer
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            // Above the exact vertical center by a relative fraction of the screen.
            verticalCenterOffset: -parent.height * m3.clockShiftFactor
        }
        spacing: Math.max(m3.spaceS, clock.displaySize * 0.04)

        Row {
            id: timeRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: clock.displaySize * 0.05

            Text {
                text: clock.hoursStr
                color: clock.smartHoursColor
                font {
                    pixelSize: clock.displaySize
                    family: clock.fontFamily
                    weight: Font.Medium
                }
                anchors.verticalCenter: parent.verticalCenter
                verticalAlignment: Text.AlignVCenter
                antialiasing: true
            }

            // Material 3 / Pixel-style colon: two round dots.
            Item {
                width: clock.displaySize * 0.14
                height: clock.displaySize * 0.58
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    anchors.centerIn: parent
                    spacing: clock.displaySize * 0.10

                    Rectangle {
                        width: clock.displaySize * 0.075
                        height: width
                        radius: width / 2
                        color: clock.smartHoursColor
                        antialiasing: true
                    }
                    Rectangle {
                        width: clock.displaySize * 0.075
                        height: width
                        radius: width / 2
                        color: clock.smartMinutesColor
                        antialiasing: true
                    }
                }
            }

            Text {
                text: clock.minutesStr
                color: clock.smartMinutesColor
                font {
                    pixelSize: clock.displaySize
                    family: clock.fontFamily
                    weight: Font.Medium
                }
                anchors.verticalCenter: parent.verticalCenter
                verticalAlignment: Text.AlignVCenter
                antialiasing: true
            }
        }

        // Date, naturally placed below the clock.
        Text {
            text: clock.dateText
            color: clock.dateColor
            anchors.horizontalCenter: parent.horizontalCenter
            font {
                pixelSize: Math.max(m3.typeNormal, clock.displaySize * 0.11)
                family: clock.fontFamily
                weight: Font.DemiBold
            }
            opacity: 0.9
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.updateTime()
    }
}
