import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  IpcHandler {
    target: "launcher"

    function toggle(): void {
      launcherPanel.visible = !launcherPanel.visible
      if (launcherPanel.visible) {
        searchInput.text = ""
        selectedIndex = -1
        searchInput.forceActiveFocus()
      }
    }
  }

  property int selectedIndex: 0

  ScriptModel {
    id: filteredApps
    objectProp: "id"
    values: {
      const all = [...DesktopEntries.applications.values];
      const q = searchInput.text.trim().toLowerCase();
      if (q === "") return all.sort((a, b) => a.name.localeCompare(b.name));
      return all.filter(d =>
        (d.name && d.name.toLowerCase().includes(q)) ||
        (d.genericName && d.genericName.toLowerCase().includes(q)) ||
        (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q))) ||
        (d.categories && d.categories.some(c => c.toLowerCase().includes(q)))
      ).sort((a, b) => {
        const an = a.name.toLowerCase();
        const bn = b.name.toLowerCase();
        const aStarts = an.startsWith(q);
        const bStarts = bn.startsWith(q);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return an.localeCompare(bn);
      });
    }
  }

  function launchApp(entry) {
    entry.execute();
    launcherPanel.visible = false;
  }

  PanelWindow {
    id: launcherPanel
    visible: false
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-launcher"

    exclusionMode: ExclusionMode.Ignore

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Dark overlay backdrop
    MouseArea {
      anchors.fill: parent
      onClicked: launcherPanel.visible = false

      Rectangle {
        anchors.fill: parent
        color: root.theme.bgOverlay
      }
    }

    // Centered launcher box
    Rectangle {
      id: launcherBox
      anchors.centerIn: parent
      width: launcherPanel.width * 0.4
      height: launcherPanel.height * 0.6
      radius: 16
      color: root.theme.bgBase
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        Text {
          text: "  Applications"
          Layout.alignment: Qt.AlignCenter
          color: root.theme.accentPrimary
          font.pixelSize: 18
          font.family: root.font
          font.bold: true
        }

        // Search bar
        Rectangle {
          Layout.fillWidth: true
          height: 44
          radius: 10
          color: root.theme.bgSurface
          border.color: root.theme.accentPrimary
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Text {
              text: ">"
              color: root.theme.textMuted
              font.pixelSize: 20
              font.family: root.font
              Layout.alignment: Qt.AlignVCenter
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              color: root.theme.textPrimary
              font.pixelSize: 20
              font.family: root.font
              clip: true
              focus: true
              Accessible.role: Accessible.EditableText
              Accessible.name: "Search applications"

              Text {
                anchors.fill: parent
                text: "Type to search..."
                color: root.theme.textMuted
                font: parent.font
                visible: !parent.text && !parent.activeFocus
                verticalAlignment: Text.AlignVCenter
              }

              onTextChanged: root.selectedIndex = text === "" ? -1 : 0

              Keys.onEscapePressed: launcherPanel.visible = false

              Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                  event.accepted = true;
                  root.selectedIndex = Math.min(root.selectedIndex + 1, resultsList.count - 1);
                  resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                } else if (event.key === Qt.Key_Up) {
                  event.accepted = true;
                  root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                  resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  event.accepted = true;
                  if (root.selectedIndex >= 0) {
                    const entry = filteredApps.values[root.selectedIndex];
                    if (entry) root.launchApp(entry);
                  }
                } else if (event.key === Qt.Key_Tab) {
                  event.accepted = true;
                  root.selectedIndex = Math.min(root.selectedIndex + 1, resultsList.count - 1);
                  resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                }
              }
            }
          }
        }

        // Results count
        Text {
          text: resultsList.count + " application" + (resultsList.count !== 1 ? "s" : "") + " found!"
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: root.font
        }

        // App list
        ListView {
          id: resultsList
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: filteredApps
          clip: true
          spacing: 5
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: root.selectedIndex
          highlightMoveDuration: 150
          highlightMoveVelocity: -1

          delegate: Rectangle {
            id: delegateRoot
            required property var modelData
            required property int index
            border.color: root.theme.bgBorder
            border.width: 0.5

            Accessible.role: Accessible.Button
            Accessible.name: (modelData.name ?? "Application") + (modelData.genericName ? " - " + modelData.genericName : "")

            width: resultsList.width
            height: appsColumnLayout.height + 20
            radius: 5
            color: (root.selectedIndex === delegateRoot.index)? root.theme.bgSelected : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              // App icon
              Item {
                width: 32
                height: 32
                Layout.alignment: Qt.AlignVCenter

                // Image {
                //   source:
                // }
                IconImage {
                  anchors.fill: parent
                  source: Quickshell.iconPath(delegateRoot.modelData.icon, Quickshell.shellDir + "/unknown-app.png")
                  visible: (delegateRoot.modelData.icon ?? "") !== ""
                }

                // Fallback icon
                // Text {
                //   anchors.centerIn: parent
                //   text: ""
                //   color: root.theme.accentPrimary
                //   font.pixelSize: 22
                //   font.family: root.font
                //   visible: (delegateRoot.modelData.icon ?? "") === ""
                // }
              }

              // App info
              ColumnLayout {
                id: appsColumnLayout
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                  text: delegateRoot.modelData.name ?? ""
                  color: root.selectedIndex === delegateRoot.index ? root.theme.accentPrimary : root.theme.textSecondary
                  font.pixelSize: 20
                  font.family: root.font
                  font.bold: root.selectedIndex === delegateRoot.index
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: delegateRoot.modelData.genericName ?? delegateRoot.modelData.comment ?? ""
                  color: root.selectedIndex === delegateRoot.index ? root.theme.textPrimary : root.theme.textMuted
                  font.pixelSize: 13
                  font.family: root.font
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                  visible: text !== ""
                }
                // test
                // Text {
                //   text: Quickshell.iconPath(delegateRoot.modelData.icon, Quickshell.shellDir + "/unknown-app.png")
                //   color: root.selectedIndex === delegateRoot.index ? root.theme.textPrimary : root.theme.textMuted
                //   font.pixelSize: 13
                //   font.family: root.font
                //   elide: Text.ElideRight
                //   Layout.fillWidth: true
                // }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launchApp(delegateRoot.modelData)
              onPositionChanged: root.selectedIndex = delegateRoot.index
            }
          }

          // Empty state
          Text {
            anchors.centerIn: parent
            text: "  No applications found"
            color: root.theme.textMuted
            font.pixelSize: 14
            font.family: root.font
            visible: resultsList.count === 0 && searchInput.text !== ""
          }
        }

        // Footer hint
        RowLayout {
          Layout.fillWidth: true
          spacing: 16

          Row {
            spacing: 4
            Rectangle {
              width: hintUp.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintUp; anchors.centerIn: parent; text: "↑↓"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font }
            }
            Text { text: "navigate"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEnter.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintEnter; anchors.centerIn: parent; text: "⏎"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font }
            }
            Text { text: "launch"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEsc.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintEsc; anchors.centerIn: parent; text: "esc"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font }
            }
            Text { text: "close"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font; anchors.verticalCenter: parent.verticalCenter }
          }

          Item { Layout.fillWidth: true }
        }
      }
    }
  }
}
