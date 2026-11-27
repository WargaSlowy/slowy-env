import QtQuick
import qs

// digits and short words: JetBrains Mono, bold. Not smaller than 26px.
// Box as line-height .85 in the concept: lineHeight does not work for single-line Text, hence negative padding.
Text {
    readonly property real lead: -0.175 * font.pixelSize
    font { family: Theme.dot; pixelSize: 44; weight: Font.Black }
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
