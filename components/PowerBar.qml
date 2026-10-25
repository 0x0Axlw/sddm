/**
 * Pixie SDDM - Status & Power bar (Material 3 icon buttons)
 *
 * Bottom-corner bar: system indicators (battery, keyboard layout) plus the
 * suspend / reboot / power actions. Itemless of position, the component only
 * draws a horizontal row of consistent circular touch targets with M3 state
 * layers; anchoring is done by the parent (Main.qml).
 */
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: powerBarRoot
    spacing: m3.spaceM

    // Static token snapshot (no runtime shell services required).
    M3 { id: m3 }

    property color textColor: "white"

    FontLoader { id: iconFont; source: "../assets/fonts/MaterialDesignIcons.ttf" }

    // M3 circular icon button: transparent at rest, tinted state layer on
    // hover (12%) / press (24%), springy press scale.
    component BarIconButton: Item {
        id: iconButton
        property string iconText: ""
        property string label: ""
        signal activated()

        Layout.preferredWidth: m3.barTouchSize
        Layout.preferredHeight: m3.barTouchSize
        opacity: enabled ? 1.0 : 0.4
        Behavior on opacity { NumberAnimation { duration: m3.durationFast } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: powerBarRoot.textColor
            opacity: !iconButton.enabled ? 0.0
                   : interaction.containsPress ? 0.24
                   : interaction.containsMouse ? 0.12 : 0.0
            Behavior on opacity { NumberAnimation { duration: m3.durationFast } }
        }

        Text {
            anchors.centerIn: parent
            text: iconButton.iconText
            color: powerBarRoot.textColor
            font.pixelSize: m3.barIconSize
            font.family: iconFont.name
        }

        scale: interaction.containsPress ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: m3.durationFast; easing.type: Easing.OutQuad } }

        MouseArea {
            id: interaction
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.activated()
        }

        Accessible.role: Accessible.Button
        Accessible.name: iconButton.label
        Accessible.onPressAction: iconButton.activated()
    }

    // --- System indicators (subtle, half-opacity, non-power) ---
    Item {
        Layout.preferredHeight: m3.barTouchSize
        Layout.preferredWidth: statusCluster.width

        Row {
            id: statusCluster
            anchors.centerIn: parent
            spacing: m3.spaceS
            opacity: 0.85

            // Battery (forced live updates; SDDM misses some signals)
            Row {
                id: batteryRow
                spacing: 4
                visible: typeof battery !== "undefined" && typeof battery.percent !== "undefined"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: batteryIcon
                    text: (typeof battery !== "undefined" && battery.charging) ? "󱐋" : "󰁹"
                    color: powerBarRoot.textColor
                    font.pixelSize: m3.barIconSize - 2
                    font.family: iconFont.name
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: batteryText
                    text: (typeof battery !== "undefined" ? battery.percent : "0") + "%"
                    color: powerBarRoot.textColor
                    font.pixelSize: m3.typeSmall
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }

                Timer {
                    interval: 5000
                    running: typeof battery !== "undefined" && battery.present
                    repeat: true
                    onTriggered: {
                        batteryText.text = battery.percent + "%"
                        batteryIcon.text = battery.charging ? "󱐋" : "󰁹"
                    }
                }
            }

            // Keyboard layout switcher (functionality preserved; subtle press)
            Item {
                visible: typeof keyboard !== "undefined" && keyboard.layouts.length > 1
                width: layoutText.width + m3.spaceS * 2
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: layoutText
                    anchors.centerIn: parent
                    text: (typeof keyboard !== "undefined" && keyboard.layouts[keyboard.currentLayout])
                          ? keyboard.layouts[keyboard.currentLayout].shortName : "US"
                    color: powerBarRoot.textColor
                    font.pixelSize: m3.typeSmall
                    font.capitalization: Font.AllUppercase
                    font.weight: Font.Medium
                }
                scale: layoutMouse.pressed ? 0.9 : 1.0
                Behavior on scale { NumberAnimation { duration: m3.durationFast } }

                function switchLayout() {
                    if (typeof keyboard !== "undefined" && keyboard.layouts.length > 0)
                        keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length;
                }

                MouseArea {
                    id: layoutMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.switchLayout()
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Switch keyboard layout"
                Accessible.onPressAction: switchLayout()
            }
        }
    }

    // --- Power actions (functionality unchanged) ---
    BarIconButton {
        iconText: "󰤄"
        label: "Suspend"
        onActivated: sddm.suspend()
    }
    BarIconButton {
        iconText: "󰑐"
        label: "Reboot"
        onActivated: sddm.reboot()
    }
    BarIconButton {
        iconText: "󰐥"
        label: "Shut down"
        onActivated: sddm.powerOff()
    }
}
