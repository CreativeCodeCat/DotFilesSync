import "../common"
import QtQuick
import QtQuick.Layouts

// The status segments in Config.segments order, each with its own accent.
RowLayout {
    spacing: 3

    Repeater {
        model: Config.segments

        delegate: RowLayout {
            id: segmentRow

            required property string modelData
            required property int index

            // the segment's name and its accent pair, read by the chips below
            readonly property string segmentName: modelData
            readonly property var segmentAccent: Config.accents[index % Config.accents.length]
            readonly property var chips: Sys.chips(segmentName)

            visible: chips.length > 0
            spacing: 3

            Repeater {
                model: segmentRow.chips

                delegate: Chip {
                    required property var modelData

                    icon: modelData.icon
                    label: modelData.label
                    segment: segmentRow.segmentName
                    accent: segmentRow.segmentAccent
                }
            }
        }
    }
}
