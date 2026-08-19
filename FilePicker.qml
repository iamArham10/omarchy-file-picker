import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "FilePickerModel.js" as FilePickerModel

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property string selectedCategory: "all"
  property var categories: ["all", "documents", "notes", "videos", "audio", "images", "code"]
  property var categoryLabels: {
    "all": "All",
    "documents": "Docs",
    "notes": "Notes",
    "videos": "Videos",
    "audio": "Audio",
    "images": "Images",
    "code": "Code"
  }
  property var categoryIcons: {
    "all": "󰈔",
    "documents": "󰈙",
    "notes": "󰎞",
    "videos": "󰕼",
    "audio": "󰎆",
    "images": "󰈟",
    "code": "󰈮"
  }
  property int categoryIndex: 0
  property int selectedIndex: 0
  property bool cursorActive: false
  property var allFiles: []
  property bool scanning: false

  // Theming using Omarchy design system tokens
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(38), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(920), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(640), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(48), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)

  readonly property string pluginSourceDir: (manifest && manifest.__sourceDir) ? manifest.__sourceDir : (Quickshell.env("HOME") + "/.config/omarchy/plugins/arh.file-picker")
  readonly property string scanScriptPath: pluginSourceDir + "/scan.sh"

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true

    if (payloadJson) {
      try {
        var payload = JSON.parse(payloadJson)
        if (payload.category && root.categories.indexOf(payload.category) !== -1) {
          root.selectedCategory = payload.category
          root.categoryIndex = root.categories.indexOf(payload.category)
        } else {
          root.selectedCategory = "all"
          root.categoryIndex = 0
        }
        if (payload.query) {
          root.filterText = String(payload.query)
        }
      } catch (e) {
        root.selectedCategory = "all"
        root.categoryIndex = 0
      }
    } else {
      root.selectedCategory = "all"
      root.categoryIndex = 0
    }

    if (root.allFiles.length === 0) {
      root.runScan(false)
    } else {
      root.rebuildDisplay()
    }

    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "arh.file-picker")
    }
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function runScan(force) {
    if (scanProcess.running) return
    root.scanning = true
    scanProcess.command = ["bash", root.scanScriptPath, "--tsv"]
    if (force) scanProcess.command.push("--force")
    scanProcess.running = true
  }

  function handleScanFinished(rawTsv) {
    root.scanning = false
    root.allFiles = FilePickerModel.parseTsv(rawTsv)
    root.rebuildDisplay()
  }

  function rebuildDisplay() {
    var filtered = FilePickerModel.filterFiles(root.allFiles, root.filterText, root.selectedCategory, 500)

    displayModel.clear()
    for (var i = 0; i < filtered.length; i++) {
      var it = filtered[i]
      displayModel.append({
        path: it.path,
        name: it.name,
        dir: it.dir,
        category: it.category,
        extension: it.extension,
        sizeFormatted: it.sizeFormatted,
        mtimeFormatted: it.mtimeFormatted,
        icon: it.icon,
        index: i
      })
    }

    if (displayModel.count === 0) {
      selectedIndex = 0
    } else if (selectedIndex >= displayModel.count) {
      selectedIndex = displayModel.count - 1
    } else if (selectedIndex < 0) {
      selectedIndex = 0
    }
    cursorActive = displayModel.count > 0

    Qt.callLater(function() {
      if (displayModel.count > 0 && resultList) {
        resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      }
    })
  }

  function setFilter(text) {
    root.filterText = text
    root.selectedIndex = 0
    root.rebuildDisplay()
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      var next = selectedIndex + delta
      if (next < 0) next = 0
      if (next >= displayModel.count) next = displayModel.count - 1
      selectedIndex = next
    }
    if (resultList) resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectCategory(delta) {
    var count = root.categories.length
    root.categoryIndex = (root.categoryIndex + delta + count) % count
    root.selectedCategory = root.categories[root.categoryIndex]
    root.selectedIndex = 0
    root.rebuildDisplay()
  }

  function setCategory(cat) {
    var idx = root.categories.indexOf(cat)
    if (idx !== -1) {
      root.categoryIndex = idx
      root.selectedCategory = cat
      root.selectedIndex = 0
      root.rebuildDisplay()
    }
  }

  function applyIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var item = displayModel.get(index)
    if (!item) return
    root.dismiss()
    Quickshell.execDetached(["xdg-open", item.path])
  }

  function openFolderIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var item = displayModel.get(index)
    if (!item) return
    root.dismiss()
    Quickshell.execDetached(["xdg-open", item.dir])
  }

  function copyPathIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var item = displayModel.get(index)
    if (!item) return
    root.dismiss()
    Quickshell.execDetached(["wl-copy", item.path])
  }

  Process {
    id: scanProcess
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleScanFinished(text)
    }
  }

  ListModel { id: displayModel }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-file-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ShiftModifier) root.selectCategory(-1)
            else root.selectCategory(1)
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_K)) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_J)) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-8)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(8)
            event.accepted = true
          } else if (event.key === Qt.Key_F5 || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_R)) {
            root.runScan(true)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (event.modifiers & Qt.AltModifier) {
              root.openFolderIndex(root.selectedIndex)
            } else if (event.modifiers & Qt.ShiftModifier) {
              root.copyPathIndex(root.selectedIndex)
            } else if (root.cursorActive) {
              root.applyIndex(root.selectedIndex)
            }
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(12)

        // ------------------------------------------------ Header: Search Input & Category Pills
        RowLayout {
          width: parent.width
          height: root.headerHeight
          spacing: Style.space(10)

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: root.cornerRadius
            color: Util.alpha(root.foreground, 0.06)
            border.width: Style.normalBorderWidth
            border.color: Util.alpha(root.border, 0.35)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: root.foreground
                opacity: 0.65
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(40)
                text: root.filterText || "Type to search files…"
                color: root.foreground
                opacity: root.filterText ? 1.0 : 0.45
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                elide: Text.ElideRight
              }
            }
          }

          // Category Selector Pills
          Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Style.space(4)

            Repeater {
              model: root.categories

              Rectangle {
                required property string modelData
                readonly property bool isActive: root.selectedCategory === modelData

                width: pillText.implicitWidth + Style.space(16)
                height: root.headerHeight - Style.space(6)
                radius: root.cornerRadius
                color: isActive ? root.selectedBackground : Util.alpha(root.foreground, 0.05)
                border.width: Style.normalBorderWidth
                border.color: isActive ? root.selectedBackground : Util.alpha(root.border, 0.2)

                Row {
                  id: pillText
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: root.categoryIcons[modelData] || "󰈔"
                    color: isActive ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    opacity: isActive ? 1.0 : 0.7
                  }

                  Text {
                    text: root.categoryLabels[modelData] || modelData
                    color: isActive ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: isActive
                    opacity: isActive ? 1.0 : 0.8
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setCategory(modelData)
                }
              }
            }
          }
        }

        // ------------------------------------------------ Main Content Split Pane
        Row {
          width: parent.width
          height: parent.height - root.headerHeight - footerBar.height - Style.space(24)
          spacing: Style.space(12)

          // Left: Results ListView
          Rectangle {
            width: parent.width * 0.58
            height: parent.height
            color: "transparent"
            clip: true

            ListView {
              id: resultList
              anchors.fill: parent
              model: displayModel
              spacing: Style.space(3)
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              delegate: Rectangle {
                id: rowItem
                required property int index
                required property string path
                required property string name
                required property string dir
                required property string category
                required property string sizeFormatted
                required property string mtimeFormatted
                required property string icon

                readonly property bool isSelected: root.cursorActive && index === root.selectedIndex

                width: ListView.view.width
                height: root.rowHeight
                radius: root.cornerRadius
                color: isSelected ? root.selectedBackground : (mouseRow.containsMouse ? Util.alpha(root.foreground, 0.04) : "transparent")

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(10)

                  // File Type Icon
                  Text {
                    text: icon
                    color: isSelected ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title + Style.space(2)
                    Layout.alignment: Qt.AlignVCenter
                  }

                  // File Name & Path
                  Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Style.space(2)

                    Text {
                      width: parent.width
                      text: name
                      color: isSelected ? root.selectedText : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: isSelected
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: dir.replace(Quickshell.env("HOME"), "~")
                      color: isSelected ? root.selectedText : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      opacity: isSelected ? 0.8 : 0.5
                      elide: Text.ElideMiddle
                    }
                  }

                  // Size Badge
                  Text {
                    text: sizeFormatted
                    color: isSelected ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    opacity: isSelected ? 0.85 : 0.55
                    Layout.alignment: Qt.AlignVCenter
                  }
                }

                MouseArea {
                  id: mouseRow
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedIndex = rowItem.index
                    root.cursorActive = true
                    root.applyIndex(rowItem.index)
                  }
                }
              }
            }

            // Empty State
            Text {
              visible: displayModel.count === 0 && !root.scanning
              anchors.centerIn: parent
              text: root.filterText ? "No matching files found" : "No files indexed in configured folders"
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            // Scanning Indicator
            Text {
              visible: root.scanning
              anchors.centerIn: parent
              text: "󰑐 Scanning folders…"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          // Vertical Separator
          Rectangle {
            width: Style.normalBorderWidth
            height: parent.height
            color: Util.alpha(root.border, 0.3)
          }

          // Right: File Detail / Preview Card
          Rectangle {
            width: parent.width * 0.42 - Style.space(12) - Style.normalBorderWidth
            height: parent.height
            radius: root.cornerRadius
            color: Util.alpha(root.foreground, 0.03)
            border.width: Style.normalBorderWidth
            border.color: Util.alpha(root.border, 0.25)
            clip: true

            property var activeFile: displayModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count ? displayModel.get(root.selectedIndex) : null

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(16)
              spacing: Style.space(10)

              // Large Icon & Name
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(12)

                Text {
                  text: parent.parent.activeFile ? parent.parent.activeFile.icon : "󰈔"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(36)
                  Layout.alignment: Qt.AlignTop
                }

                Column {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Text {
                    width: parent.width
                    text: parent.parent.parent.activeFile ? parent.parent.parent.activeFile.name : "Select a file"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    elide: Text.ElideRight
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                  }

                  Text {
                    text: parent.parent.parent.activeFile ? parent.parent.parent.activeFile.category.toUpperCase() : ""
                    color: root.selectedBackground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              // Live Image Thumbnail Preview (if image category)
              Rectangle {
                visible: parent.parent.activeFile !== null && parent.parent.activeFile.category === "images"
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(110)
                radius: root.cornerRadius
                color: Util.alpha(root.foreground, 0.04)
                border.width: Style.normalBorderWidth
                border.color: Util.alpha(root.border, 0.2)
                clip: true

                Image {
                  anchors.fill: parent
                  anchors.margins: Style.space(4)
                  source: (parent.parent.parent.activeFile && parent.parent.parent.activeFile.category === "images") ? Util.fileUrl(parent.parent.parent.activeFile.path) : ""
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  smooth: true
                }
              }

              // Metadata Properties
              Column {
                Layout.fillWidth: true
                spacing: Style.space(6)

                Rectangle {
                  width: parent.width
                  height: Style.normalBorderWidth
                  color: Util.alpha(root.border, 0.2)
                }

                // File Size
                RowLayout {
                  width: parent.width
                  Text {
                    text: "Size:"
                    color: root.foreground
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    Layout.preferredWidth: Style.space(70)
                  }
                  Text {
                    text: parent.parent.parent.activeFile ? parent.parent.parent.activeFile.sizeFormatted : "-"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }
                }

                // Modified Date
                RowLayout {
                  width: parent.width
                  Text {
                    text: "Modified:"
                    color: root.foreground
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    Layout.preferredWidth: Style.space(70)
                  }
                  Text {
                    text: parent.parent.parent.activeFile ? parent.parent.parent.activeFile.mtimeFormatted : "-"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }
                }

                // Full Path
                Column {
                  width: parent.width
                  spacing: Style.space(2)
                  Text {
                    text: "Location:"
                    color: root.foreground
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    width: parent.width
                    text: parent.parent.parent.activeFile ? parent.parent.parent.activeFile.path : "-"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    opacity: 0.85
                  }
                }
              }

              Item { Layout.fillHeight: true }

              // Action Buttons
              Column {
                Layout.fillWidth: true
                spacing: Style.space(6)

                // Open File Button
                Rectangle {
                  width: parent.width
                  height: Style.space(32)
                  radius: root.cornerRadius
                  color: root.selectedBackground

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(6)
                    Text { text: "󰅩"; color: root.selectedText; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                    Text { text: "Open File (Enter)"; color: root.selectedText; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.applyIndex(root.selectedIndex)
                  }
                }

                // Open Folder Button
                Rectangle {
                  width: parent.width
                  height: Style.space(30)
                  radius: root.cornerRadius
                  color: Util.alpha(root.foreground, 0.07)
                  border.width: Style.normalBorderWidth
                  border.color: Util.alpha(root.border, 0.25)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(6)
                    Text { text: ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    Text { text: "Open Folder (Alt+Enter)"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openFolderIndex(root.selectedIndex)
                  }
                }

                // Copy Path Button
                Rectangle {
                  width: parent.width
                  height: Style.space(30)
                  radius: root.cornerRadius
                  color: Util.alpha(root.foreground, 0.07)
                  border.width: Style.normalBorderWidth
                  border.color: Util.alpha(root.border, 0.25)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(6)
                    Text { text: "󰅍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    Text { text: "Copy Path (Shift+Enter)"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyPathIndex(root.selectedIndex)
                  }
                }
              }
            }
          }
        }

        // ------------------------------------------------ Footer: Status & Keyboard Cheatsheet
        RowLayout {
          id: footerBar
          width: parent.width
          height: Style.space(22)

          Text {
            text: displayModel.count + " files " + (root.filterText ? "matched" : "indexed")
            color: root.foreground
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Item { Layout.fillWidth: true }

          Row {
            spacing: Style.space(12)

            Text {
              text: "Tab: Category"
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              text: "F5: Refresh"
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              text: "Esc: Close"
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
