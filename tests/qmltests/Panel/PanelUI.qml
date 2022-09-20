/*
 * Copyright 2013-2015 Canonical Ltd.
 * Copyright 2020 UBports Foundation
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import QtQuick.Layouts 1.1
import QtTest 1.0
import Unity.Test 0.1
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItem
import Unity.Application 0.1
import QMenuModel 0.1
import Ubuntu.Telephony 0.1 as Telephony
import AccountsService 0.1
import Unity.InputInfo 0.1
import "../../../qml/Panel"
import "../../../qml/Components/PanelState"
import "../Stage"
import ".."

PanelTest {
    id: root
    width: units.gu(120)
    height: units.gu(71)
    color: "black"

    property alias panel: panel
    property alias mouseEmulation: mouseEmulation
    property alias appMenuData: appMenuData
    property alias aboutToShowCalledSpy: aboutToShowCalledSpy
    property alias itemArea: itemArea
    property alias backgroundMouseArea: backgroundMouseArea
    property alias phoneCall: phoneCall

    Binding {
        target: QuickUtils
        property: "keyboardAttached"
        value: keyboardAttached.checked
    }

    SurfaceManager { id: sMgr }
    ApplicationMenuDataLoader {
        id: appMenuData
        surfaceManager: sMgr
    }

    Component.onCompleted: {
        theme.name = "Ubuntu.Components.Themes.SuruDark"
    }

    Rectangle {
        anchors.fill: parent
        color: "darkgrey"
    }

    SignalSpy {
        id: aboutToShowCalledSpy
        signalName: "aboutToShowCalled"
    }

    RowLayout {
        anchors.fill: parent
        //anchors.margins: units.gu(1)
        clip: true

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            id: itemArea
            color: backgroundMouseArea.pressed ? "black" : "gray"

            MouseArea {
                id: backgroundMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { console.log(" at "+mouse.x +" " +mouse.y )

                        mouse.accepted = false}

                Panel {
                    id: panel
                    anchors.fill: parent
                    mode: modeSelector.model[modeSelector.selectedIndex]

                    applicationMenus {
                        model: menuData.checked ? menuModel : null

                        readonly property var menuModel: UnityMenuModel {
                            modelData: appMenuData.generateTestData(10, 4, 2, 3, "menu")
                        }

                        hides: [ panel.indicators ]
                    }

                    indicators {
                        model: root.indicatorsModel
                        hides: [ panel.applicationMenus ]
                    }
                     onExpandedChanged: {
                         if (expanded) {
                             removeIndicator(6)
                         } else {
                             insertIndicator(6)
                         }
                     }
                    Rectangle {
                        id: notchRect
                        anchors {
                            top: parent.top
                            topMargin: panel.indicators.height
                            left: parent.horizontalCenter
                            leftMargin: notchX.value
                        }
                        height: units.gu(0.5)
                        width: notchWidth.value
                        // x: units.gu(15) //(parent.width - width) / 2
                        // x: (parent.width - width) / 2
                        // x: (parent.width - width) / 2
                        color: UbuntuColors.red
                        visible: true
                        // opacity: 0.5
                        property real y1: y / 2
                        // property real relX: x + width //x-panel.listView.x + width
                        property real relX: x-panel.listView.x + width
                        property real relY1: y1 - panel.listView.y
                        property real span: units.gu(0.5)
                        // onXChanged: {
                        //     // console.log(x)
                        //     update()
                        // }
                        // onWidthChanged: update()
                        Component.onCompleted: update()
                        function update() {
                            console.log("updating notch", relX, relY1)
                            console.log("listview width", panel.listView.width, "x", panel.listView.x)
                            console.log("panel width", panel.width, "x", panel.x)
                            var hiddenIndicator = panel.indicators.indicatorAt(relX, relY1)
                            // var hiddenIndicator = panel.indicators.indicatorAt(relX, 0)
                            if (hiddenIndicator == null) {
                                console.log("No indicator covered by the notch")
                                return
                            }
                            var hiddenIndicatorName = hiddenIndicator.objectName.split("-panelItem")[0]
                            console.log("indicator at right "+hiddenIndicatorName)
                            var hiddenIndicatorIndex = getIndicatorIndexFromIdentifier(hiddenIndicatorName)
                            // console.log("indicator index at right "+hiddenIndicatorIndex)

                            var p
                            panel.indicators.setCurrentItemIndex(hiddenIndicatorIndex + 1)
                            console.log("right indicator undefined", panel.listView.currentItem == undefined)
                            // item to the right of the notch
                            var t_str = panel.listView.currentItem.objectName.split("-panelItem")[0]
                            console.log("new current item (t)", t_str)
                            var rightIndicatorIndex = getIndicatorIndexFromIdentifier(t_str)
                            console.log("index of indicator at the notch right", rightIndicatorIndex)

                            var rightIndicatorX = panel.listView.currentItem != undefined ? panel.indicators.getCurrentItemX() //panel.listView.currentItem.x
                                                                                          : panel.listView.x + panel.listView.width
                            console.log("rightIndicatorX", rightIndicatorX)

                            //// x coords at the right of the item t
                            // var p = t.x + t.width
                            // x coords at the left of the item t
                            console.log("listView x:", panel.listView.x, "listView width:", panel.listView.width)
                            panel.indicators.setCurrentItemIndex(hiddenIndicatorIndex - 1)
                            // console.log("element index at right of the notch: "+hiddenIndicator)

                            var notchIndex = getIndicatorIndexFromIdentifier("notch")
                            console.log("notch index: " + notchIndex)
                            if (notchIndex === hiddenIndicatorIndex) {
                                if (panel.listView.currentItem != undefined) {
                                    // console.log(p, relX, panel.listView.currentItem.width)
                                    if(p - relX > panel.listView.currentItem.width)
                                        moveNotch(hiddenIndicatorIndex - 1)
                                }
                            }
                            // else if (hiddenIndicator != "") {
                            else {
                                moveNotch(hiddenIndicatorIndex)
                            }
                            console.log("panel/listView delta:", -Math.max(panel.listView.width - panel.width, 0))
                            panel.notchW = rightIndicatorX - Math.max(panel.listView.width - panel.width, 0) - relX + width + span
                            console.log("notch width", panel.notchW, "\n")
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: false

            ListItem.ItemSelector {
                id: modeSelector
                Layout.fillWidth: true
                activeFocusOnPress: false
                text: "Mode"
                model: ["staged", "windowed" ]
                onSelectedIndexChanged: {
                    panel.mode = model[selectedIndex];
                    keyboardAttached.checked = panel.mode == "windowed"
                    windowControlsCB.checked = panel.mode == "windowed"
                }
            }

            Button {
                id: nButton
                Layout.fillWidth: true
                text: "Update notch"
                onClicked: notchRect.update()
            }

            Slider {
                id: notchWidth
                maximumValue: units.gu(20)
                minimumValue: units.gu(1)
                width: nButton.width
                live: true
                value: units.gu(3)
            }

            Slider {
                id: notchX
                maximumValue: units.gu(20)
                minimumValue: units.gu(-20)
                width: nButton.width
                live: true
                value: units.gu(0)
            }
            RowLayout {
                Button {
                    text: "<"
                    Layout.fillWidth: true
                    onClicked: {
                        var notchIndex = getIndicatorIndexFromIdentifier("notch")
                        moveNotch(notchIndex-1)
                    }
                }
                Button {
                    text: "+"
                    Layout.fillWidth: true
                    onClicked: {
                        panel.notchW += units.gu(1)
                    }
                }
                Button {
                    text: "-"
                    Layout.fillWidth: true
                    onClicked: {
                        panel.notchW -= units.gu(1)
                    }
                }
                Button {
                    text: ">"
                    Layout.fillWidth: true
                    onClicked: {
                        var notchIndex = getIndicatorIndexFromIdentifier("notch")
                        moveNotch(notchIndex+1)
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: panel.indicators.shown ? "Hide Indicators" : "Show Indicators"
                onClicked: {
                    if (panel.indicators.shown) {
                        panel.indicators.hide();
                    } else {
                        panel.indicators.show();
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: panel.applicationMenus.shown ? "Hide Menu" : "Show Menu"
                onClicked: {
                    if (panel.applicationMenus.shown) {
                        panel.applicationMenus.hide();
                    } else {
                        panel.applicationMenus.show();
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: callManager.hasCalls ? "Remove call" : "Add call"
                onClicked: {
                    if (callManager.foregroundCall) {
                        callManager.foregroundCall = null;
                    } else {
                        callManager.foregroundCall = phoneCall;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    id: fullscreenCB
                    checked: false
                }
                Label {
                    text: "Main app is fullscreen"
                    color: "white"
                }
            }

            Binding {
                target: panel
                property: "fullscreenMode"
                value: fullscreenCB.checked
            }

            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    id: menuData
                    checked: true
                }
                Label {
                    text: "Application Menu has data"
                    color: "white"
                }
            }

            Binding {
                target: PanelState
                property: "decorationsVisible"
                value: windowControlsCB.checked
            }

            Binding {
                target: PanelState
                property: "title"
                value: "Fake window title"
            }

            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    id: windowControlsCB
                    onClicked: PanelState.decorationsVisible = checked
                }
                Label {
                    text: "Show window decorations"
                    color: "white"
                }
            }

            Rectangle {
                Layout.preferredHeight: units.dp(1);
                Layout.fillWidth: true;
                color: "black"
            }

            Rectangle {
                Layout.preferredHeight: units.dp(1);
                Layout.fillWidth: true;
                color: "black"
            }

            Repeater {
                model: root.originalModelData
                RowLayout {
                    CheckBox {
                        checked: true
                        onCheckedChanged: checked ? insertIndicator(index) : removeIndicator(index);
                    }
                    Label {
                        Layout.fillWidth: true
                        text: modelData["identifier"]
                        color: "white"
                    }

                    CheckBox {
                        checked: true
                        onCheckedChanged: setIndicatorVisible(index, checked);
                    }
                    Label {
                        text: "visible"
                        color: "white"
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: units.dp(1);
                Layout.fillWidth: true;
                color: "black"
            }

            MouseTouchEmulationCheckbox {
                id: mouseEmulation
                color: "white"
                checked: panel.mode == "staged"
            }

            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    id: keyboardAttached
                }
                Label {
                    text: "Keyboard Attached"
                    color: "white"
                }
            }
        }
    }

    Telephony.CallEntry {
        id: phoneCall
        phoneNumber: "+447812221111"
    }
}
