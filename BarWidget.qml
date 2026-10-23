import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "io.github.abdxdev.edge-glow"

  readonly property string serviceId: "io.github.abdxdev.edge-glow"
  readonly property var glow: serviceSource.service
  readonly property bool glowEnabled: glow ? !!glow.enabled : false
  readonly property bool glowRunning: glow ? !!glow.running : false
  readonly property string glowMode: glow ? String(glow.mode) : "empty"
  readonly property int glowIntensity: glow ? Number(glow.intensity) : 100
  readonly property string glowError: glow ? String(glow.lastError || "") : ""
  readonly property color foreground: root.bar ? root.bar.foreground : Color.foreground
  readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(root.foreground, 1.4)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property var modeOptions: [
    { value: "always", label: "Always" },
    { value: "empty", label: "Only when empty" }
  ]
  readonly property string heroMeta: {
    if (!glow) return "UNAVAILABLE"
    if (!glowEnabled) return "PREVIEW OFF"
    if (!glowRunning) return "STARTING…"
    return (glowMode === "always" ? "ALWAYS" : "ONLY WHEN EMPTY")
      + " · " + glowIntensity + "%"
  }
  readonly property string tooltip: glow === null
    ? "Edge Glow unavailable"
    : (root.glowEnabled
      ? "Edge Glow — right-click to turn off"
      : "Edge Glow — right-click to turn on")

  property bool panelOpen: false

  function open() {
    panelOpen = true
  }

  function close() {
    panelOpen = false
  }

  function toggle() {
    panelOpen = !panelOpen
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button

    anchors.fill: parent
    bar: root.bar
    // A square wave, in the same white icon colour native bar widgets use.
    text: "\uef9d"
    active: root.glowEnabled
    useActiveColor: false
    dimmed: !root.glowEnabled
    interactive: root.bar !== null
    tooltipText: root.tooltip
    onPressed: function(clickedButton) {
      if (clickedButton === Qt.RightButton) {
        if (root.glow) root.glow.toggle()
      } else {
        root.toggle()
      }
    }
  }

  ServiceSource {
    id: serviceSource

    bar: root.bar
    serviceId: root.serviceId
    // The shell's own instance keeps the IPC target.
    fallback: Component { Service { ipcEnabled: false } }
  }

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.panelOpen
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(560))

    content: PanelKeyCatcher {
      implicitHeight: panelColumn.implicitHeight
      anchors.fill: parent
      onCloseRequested: root.close()

      ScrollView {
        id: scrollArea

        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height
          ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn

          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // ---------- Hero: wave · title/status · on/off ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight,
              heroLabels.implicitHeight, powerSwitch.implicitHeight)

            Text {
              id: heroIcon

              textFormat: Text.PlainText
              text: button.text
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels

              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: powerSwitch.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Edge Glow"
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.heroMeta
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }

            ToggleSwitch {
              id: powerSwitch

              checked: root.glowEnabled
              foreground: root.foreground
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              onToggled: if (root.glow) root.glow.enabled = !root.glowEnabled

              PanelToolTip {
                visible: powerSwitch.containsMouse
                text: root.glowEnabled
                  ? "Turn the preview off"
                  : "Turn the preview on"
                fontFamily: root.fontFamily
              }
            }
          }

          Text {
            width: parent.width
            visible: root.glowError !== ""
            text: root.glowError
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          // ---------- Show on ----------
          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "SHOW ON"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              id: modeRow

              width: parent.width
              columns: root.modeOptions.length
              spacing: Style.spacing.xs

              readonly property real cellWidth: columns > 0
                ? (width - spacing * (columns - 1)) / columns
                : 0

              Repeater {
                model: root.modeOptions

                ModePill {
                  required property var modelData

                  option: modelData
                  width: modeRow.cellWidth
                }
              }
            }
          }

          // ---------- Intensity ----------
          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(intensityHeader.implicitHeight,
                intensityPercent.implicitHeight)

              PanelSectionHeader {
                id: intensityHeader

                text: "INTENSITY"
                foreground: root.foreground
                fontFamily: root.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: intensityPercent

                textFormat: Text.PlainText
                text: Math.round(slider.dragging ? slider.liveValue : root.glowIntensity) + "%"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              width: parent.width
              height: slider.implicitHeight + Style.spacing.controlGap
              foreground: root.foreground
              outline: true

              PanelSlider {
                id: slider

                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 0
                maximum: 200
                step: 5
                integer: true
                value: root.glowIntensity
                onReleased: function(value) {
                  if (root.glow) root.glow.intensity = Math.round(value)
                }
              }
            }
          }

          Item {
            width: parent.width
            height: Style.space(4)
          }
        }
      }
    }
  }

  component ModePill: Button {
    id: pill

    required property var option

    text: pill.option.label
    fontSize: Style.font.caption
    foreground: root.foreground
    fontFamily: root.fontFamily
    horizontalPadding: Style.spacing.sm
    verticalPadding: Style.spacing.controlPaddingY
    bordered: true

    active: root.glowMode === pill.option.value

    onClicked: if (root.glow) root.glow.mode = pill.option.value
  }
}
