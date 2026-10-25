/**
 * Pixie SDDM - Material 3 design tokens (compatibility bridge)
 *
 * Translated from the end-4 style shell design system
 * (~/.config/quickshell/end4-pC/modules/common/Apppearance.qml):
 *   - rounding scale mirrors Appearance.rounding,
 *   - type scale mirrors Appearance.font.pixelSize,
 *   - motion durations/curves mirror Appearance.animationCurves,
 *   - spacing follows the values the shell uses in its widgets.
 *
 * M3 color roles (primary/onPrimary/surface...) are supplied by Main.qml -
 * they depend on the wallpaper-responsive palette (Matugen / autoColor) and
 * stay bound there. This file intentionally holds only static constants so
 * any component can instantiate it independently.
 */
import QtQuick

QtObject {
    id: root

    // --- Rounding (end-4 Appearance.rounding) ---
    readonly property int radiusUnsharpen: 2
    readonly property int radiusVerySmall: 8
    readonly property int radiusSmall: 12
    readonly property int radiusNormal: 17
    readonly property int radiusLarge: 23
    readonly property int radiusVeryLarge: 30
    readonly property int radiusFull: 9999

    // --- Spacing (values used across the shell's widgets) ---
    readonly property int spaceXS: 4
    readonly property int spaceS: 8
    readonly property int spaceM: 12
    readonly property int spaceL: 16
    readonly property int spaceXL: 24
    readonly property int spaceXXL: 40

    // --- Type scale (end-4 Appearance.font.pixelSize) ---
    readonly property int typeSmaller: 12
    readonly property int typeSmall: 15
    readonly property int typeNormal: 16
    readonly property int typeLarge: 17
    readonly property int typeLarger: 19
    readonly property int typeHuge: 22
    readonly property int typeTitle: 24

    // --- Control sizes (pill / FAB conventions) ---
    readonly property int controlPillHeight: 36
    readonly property int controlPillWidth: 180
    readonly property int controlFabSize: 64
    readonly property int popupWidth: 260

    // --- Motion (end-4 animationCurves; durations in ms) ---
    readonly property int durationFast: 150
    readonly property int durationNormal: 250
    readonly property int durationLarge: 400
    readonly property list<real> curveEmphasizedDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property list<real> curveStandard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]

    // --- Clock composition (relative, resolution independent) ---
    readonly property real clockHeightFactor: 0.17   // glyph size × lock height
    readonly property real clockWidthFactor: 0.42    // glyph-run fit × lock width
    readonly property real clockMinSize: 72
    readonly property real clockMaxSize: 260
    readonly property real clockShiftFactor: 0.22    // offset above vertical center × height

    // --- Avatar composition (relative to the login card) ---
    readonly property real avatarMinSize: 96
    readonly property real avatarMaxSize: 140
    readonly property real avatarCardFactor: 0.3     // diameter × card width
    readonly property real avatarEdgeTrim: 1.08      // zoom that shaves airy image borders
}
