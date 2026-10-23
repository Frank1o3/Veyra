pragma Singleton
import Quickshell

// Static design tokens — not wallust-generated, hand-tuned.
// Mirrors the "glass" look from your current waybar/style.css,
// pushed toward deeper layered translucency + softer contact shadows
// to match the sddm-glass login theme.
Singleton {
    readonly property int radius: 16
    readonly property int radiusLarge: 22
    readonly property int spacing: 6
    readonly property int barHeight: 45
    readonly property int cardRadius: 14
    readonly property int cardPadding: 14
    readonly property int sectionSpacing: 18

    readonly property string fontFamily: "SpaceMono Nerd Font"
    readonly property int fontSize: 12

    readonly property real glassOpacity: 0.62
    readonly property real hoverOpacity: 0.22
    readonly property real panelOpacity: 0.82

    readonly property real panelSurfaceOpacity: 0.14
    readonly property real panelBorderOpacity: 0.18
    readonly property real accentStrength: 0.92

    readonly property int animFast: 150
    readonly property int animNormal: 250

    // ---------------------------------------------------------------
    // Glass depth tokens
    // ---------------------------------------------------------------
    // A soft, wide "ambient" shadow gives panels a sense of floating.
    // A tighter "contact" shadow anchors them to what's behind them.
    // Using both together (rather than one big shadow) is what reads
    // as "glass" instead of "flat card with a blur."
    readonly property string shadowColorAmbient: "#55000000"
    readonly property string shadowColorContact: "#99000000"

    readonly property int shadowRadiusSmall: 22   // widgets, toasts, buttons
    readonly property int shadowRadiusMedium: 30  // bar pill, launcher, power menu
    readonly property int shadowRadiusLarge: 42   // control center dropdown

    readonly property int shadowOffsetSmall: 3
    readonly property int shadowOffsetMedium: 6
    readonly property int shadowOffsetLarge: 10

    // Top-edge highlight streak, mimicking light catching glass.
    readonly property real glassHighlightOpacity: 0.09
    readonly property real glassHighlightHeightRatio: 0.42

    // Faint accent-tinted layer stacked under the highlight for
    // a bit of color depth instead of pure neutral glass.
    readonly property real glassTintOpacity: 0.035

    readonly property real glassInnerBorderOpacity: 0.07
}
