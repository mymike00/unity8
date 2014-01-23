import QtQuick 2.0
import Ubuntu.Components 0.1
import Ubuntu.Gestures 0.1
import Unity.Application 0.1
import Utils 0.1
import "../Components"

/*

*/

Item {
    id: root

    // Controls to be set from outside
    property bool shown: false
    property bool moving: false
    property int dragAreaWidth

    // State information propagated to the outside
    readonly property bool painting: mainScreenshotImage.visible || fadeInScreenshotImage.visible || appSplash.visible
    onPaintingChanged: print("**********************+ painting changed", painting)

    onMovingChanged: {
        if (moving) {
            priv.requestNewScreenshot();
        } else {
            mainScreenshotImage.visible = false;
        }
    }

    Connections {
        target: ApplicationManager

        onFocusRequested: {
            priv.switchToApp(appId);
        }

        onFocusedApplicationIdChanged: {
            if (ApplicationManager.focusedApplicationId.length > 0) {
                if (priv.secondApplicationStarting || priv.applicationStarting) {
                    appSplashTimer.start();
                } else {
                    mainScreenshotImage.src = ApplicationManager.findApplication(ApplicationManager.focusedApplicationId).screenshot
                }
            }
        }

        onApplicationAdded: {
            if (!priv.focusedApplication) {
                mainScreenshotImage.src = "";
                mainScreenshotImage.visible = false;
                priv.applicationStarting = true;
            } else {
                mainScreenshotImage.src = "foobar";
                priv.newFocusedAppId = appId;
                priv.secondApplicationStarting = true;
                priv.requestNewScreenshot();
            }
        }
    }

    QtObject {
        id: priv

        property string focusedAppId: ApplicationManager.focusedApplicationId
        property var focusedApplication: ApplicationManager.findApplication(focusedAppId)
        property url focusedScreenshot: focusedApplication ? focusedApplication.screenshot : ""

        property bool waitingForScreenshot: false

        property bool applicationStarting: false
        property bool secondApplicationStarting: false

        property string newFocusedAppId

        onFocusedScreenshotChanged: {
            if (root.moving && priv.waitingForScreenshot) {
                mainScreenshotImage.anchors.leftMargin = 0;
                mainScreenshotImage.src = ApplicationManager.findApplication(ApplicationManager.focusedApplicationId).screenshot;
                mainScreenshotImage.visible = true;
            } else if (priv.secondApplicationStarting && priv.waitingForScreenshot) {
                applicationSwitchingAnimation.start();
            }
            waitingForScreenshot = false;
        }

        function requestNewScreenshot() {
            waitingForScreenshot = true;
            ApplicationManager.updateScreenshot(ApplicationManager.focusedApplicationId);
        }

        function switchToApp(appId) {
            priv.newFocusedAppId = appId;
            applicationSwitchingAnimation.start();
            grantFocusTimer.start();
        }

    }

    // FIXME: the signal connection seems to get lost with the fake application manager.
    // Check with Qt 5.2, see if we can remove this Connections object
    Connections {
        target: priv.focusedApplication
        onScreenshotChanged: priv.focusedScreenshot = priv.focusedApplication.screenshot
    }

    Timer {
        id: grantFocusTimer
        // Delay the actual switch to be covered by the animation for sure.
        // 1) If we switch before starting the animation, the Mir event loop paints before the Qt event loop => flickering
        // 2) If we do the switch after the animation, the panel wouldn't fade in early enough.
        interval: UbuntuAnimation.SlowDuration / 4
        repeat: false
        onTriggered: {
            ApplicationManager.focusApplication(priv.newFocusedAppId);
        }
    }

    Timer {
        id: appSplashTimer
        // This is to show the splash screen a bit longer.
        // Mir signals us that the newly started app has gotten focus before it paints something on the screen
        // This would result in the old app surface becoming visible for a bit.
        // FIXME: change appManager to only change the focusedApplicationId when the surface is ready to be shown.
        interval: 1500
        repeat: false
        onTriggered: {
            priv.applicationStarting = false;
            priv.secondApplicationStarting = false;
        }
    }

    SequentialAnimation {
        id: applicationSwitchingAnimation
        // setup
        PropertyAction { target: mainScreenshotImage; property: "anchors.leftMargin"; value: 0 }
        // PropertyAction seems to fail when secondApplicationStarting and we didn't have another screenshot before
        ScriptAction { script: mainScreenshotImage.src = priv.focusedScreenshot }
        PropertyAction { target: mainScreenshotImage; property: "visible"; value: true }
        PropertyAction { target: fadeInScreenshotImage; property: "source"; value: ApplicationManager.findApplication(priv.newFocusedAppId).screenshot }
        PropertyAction { target: fadeInScreenshotImage; property: "visible"; value: true }
        PropertyAction { target: fadeInScreenshotImage; property: "opacity"; value: 0 }
        PropertyAction { target: fadeInScreenshotImage; property: "scale"; value: .8 }


        // The actual animation
        ParallelAnimation {
            UbuntuNumberAnimation { target: mainScreenshotImage; property: "anchors.leftMargin"; to: root.width; duration: UbuntuAnimation.SlowDuration }
            UbuntuNumberAnimation { target: fadeInScreenshotImage; property: "opacity"; to: 1; duration: UbuntuAnimation.SlowDuration }
            UbuntuNumberAnimation { target: fadeInScreenshotImage; property: "scale"; to: 1; duration: UbuntuAnimation.SlowDuration }
        }

        // restore stuff
        PropertyAction { target: fadeInScreenshotImage; property: "visible"; value: false }
        PropertyAction { target: mainScreenshotImage; property: "visible"; value: false }
    }

    // FIXME: Drop this and make the imageprovider show a splashscreen instead
    Rectangle {
        id: appSplash2
        anchors.fill: parent
        color: "white"
        visible: priv.secondApplicationStarting
    }
    Image {
        id: fadeInScreenshotImage
        anchors { left: parent.left; bottom: parent.bottom }
        width: parent.width
        scale: .7
        visible: false
    }

    Rectangle {
        id: appSplash
        anchors.fill: parent
        color: "white"
        visible: priv.applicationStarting
    }
    Image {
        id: mainScreenshotImage
        anchors { left: parent.left; bottom: parent.bottom }
        width: parent.width

        property string src
        source: src
        visible: false
    }

    EdgeDragArea {
        id: coverFlipDragArea
        direction: Direction.Leftwards

        //enabled: root.available
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
        width: root.dragAreaWidth

        onTouchXChanged: {
            if (!dragging && !priv.waitingForScreenshot) {
                priv.requestNewScreenshot();
            }
            if (dragging && !priv.waitingForScreenshot) {
                coverFlickable.contentX = -touchX
            }
        }

        onDraggingChanged: {
            if (!dragging) {
                coverFlip.snap();
            }
        }
    }

    Rectangle {
        id: coverFlipBackground
        anchors.fill: parent
        color: "black"
        visible: coverFlip.visible
    }

    InputFilterArea {
        anchors.fill: root
        blockInput: coverFlip.visible
    }

    Flickable {
        id: coverFlickable
        anchors.fill: root
        contentHeight: height
        contentWidth: width * 2 + ((ApplicationManager.count - 2) * root.width * coverFlip.tileDistance * 1.5)
        flickableDirection: Qt.Horizontal
        enabled: coverFlip.visible

        property bool passedFirstStage: false

        onContentXChanged: {
            if (coverFlickable.passedFirstStage && contentX < width * coverFlip.progressMarker2) {
                contentX = width * coverFlip.progressMarker2;
                return;
            }
            var progress = contentX / width
            if (progress > coverFlip.progressMarker2) {
                coverFlickable.passedFirstStage = true;
            }
            coverFlip.progress = progress;
        }

        Row {
            id: coverFlip
            height: parent.height
            // The MouseAreas on the AppImages need to be children of the flickable in order to make focus stealing
            // for flicking vs. clicking work correctly.
            // However, for the animation calculations to become easier we don't want the row to move so we don't
            // always have to take contentX into account. So lets just compensate the flickable's movement here.
            x: coverFlickable.contentX
            visible: progress > 0

            property real progress: 0
            property real startAngle: 45
            property int endAngle: 10

            property real maxScale: 1.4
            property real minScale: .6

            // Markers: relative screen position from right to left
            // marks the line where first application is finished moving in from the right
            property real progressMarker1: 0.15
            property real progressMarker2: 0.5

            property real tileDistance: 0.1

            property bool animatingBack: false

            property real tileWidth: root.width

            property real oldProgress: 0
            onProgressChanged: {
                if (coverFlipDragArea.dragging) {
                    if (oldProgress < coverFlip.progressMarker2 && progress >= coverFlip.progressMarker2) {
                        ApplicationManager.move(0, 1)
                    } else if (oldProgress >= coverFlip.progressMarker2 && progress < coverFlip.progressMarker2) {
                        ApplicationManager.move(0, 1)
                    }
                }
                oldProgress = progress;
            }

            function snap() {
                if (coverFlip.progress < coverFlip.progressMarker1) {
                    snapAnimation.targetContentX = 0
                    snapAnimation.targetAppId = ApplicationManager.get(0).appId;
                } else if (coverFlip.progress < coverFlip.progressMarker2) {
                    snapAnimation.targetContentX = root.width * coverFlip.progressMarker2
                    snapAnimation.targetAppId = ApplicationManager.get(1).appId;
                } else if (coverFlip.progress < 0.6) {
                    snapAnimation.targetContentX = root.width * coverFlip.progressMarker2
                    snapAnimation.targetAppId = ApplicationManager.get(0).appId;
                } else {
                    if (ApplicationManager.count == 3) {
                        snapAnimation.targetContentX = root.width * 1.1;
                    } else {
                        snapAnimation.targetContentX = root.width * 1.25;
                    }
                    snapAnimation.targetAppId = "";
                }
                snapAnimation.start();
            }

            function selectItem(index) {
                tileRepeater.itemAt(index).select();
            }

            SequentialAnimation {
                id: snapAnimation
                property int targetContentX: 0
                property string targetAppId

                UbuntuNumberAnimation {
                    target: coverFlickable
                    properties: "contentX"
                    to: snapAnimation.targetContentX
                    duration: UbuntuAnimation.SnapDuration
                }
                ScriptAction {
                    script: {
                        if (snapAnimation.targetAppId) {
                            coverFlickable.passedFirstStage = false;
                            ApplicationManager.focusApplication(snapAnimation.targetAppId);
                        }
                        if (snapAnimation.targetContentX == root.width * coverFlip.progressMarker2) {
                            coverFlickable.contentX = 0;
                        }
                    }
                }
            }

            Repeater {
                id: tileRepeater
                model: ApplicationManager

                Item {
                    id: appItem
                    height: parent.height
                    width: coverFlip.tileWidth

                    // This is the main progress, of the gesture, the same for every tile
                    property real progress: coverFlip.progress
                    // The progress, translated for the second stage of the animation, after the first app switch has happened
                    // Additionally it speeds it up a bit, depending on the distance of the tile
                    property real translatedProgress: appItem.progress - coverFlip.progressMarker2 - (coverFlip.tileDistance * (index-1))

                    // Is this tile selected by a click?
                    property bool isSelected: false
                    // We need to remember some values when app is selected to be able to animate it to the foreground
                    property real selectedXTranslation: 0
                    property real selectedTranslatedProgress: 0
                    property real selectedProgress: 0
                    property real selectedAngle: 0
                    property real selectedXScale: 0

                    function select() {
                        appItem.selectedXTranslation = appItem.xTranslation;
                        appItem.selectedAngle = appItem.angle;
                        appItem.selectedXScale = appItem.xScale;
                        appItem.selectedTranslatedProgress = appItem.translatedProgress - coverFlip.progressMarker2;
                        appItem.selectedProgress = appItem.progress - coverFlip.progressMarker2;
                        appItem.isSelected = true;
                        switchToAppAnimation.targetContentX = coverFlip.progressMarker2 * root.width
                        switchToAppAnimation.start();
                    }

                    property int xTranslation: {
                        var xTranslate = 0;
                        var minXTranslate = -index * root.width + index * units.dp(3);
                        switch (index) {
                        case 0:
                            if (appItem.progress < coverFlip.progressMarker2) {
                                var progress = appItem.progress
                                var progressDiff = coverFlip.progressMarker2
                                var translateDiff = -root.width * 0.25
                                // progress : progressDiff = translate : translateDiff
                                xTranslate = progress * translateDiff / progressDiff
                            }
                            break;
                        case 1:
                            if (appItem.progress < coverFlip.progressMarker2) {
                                var progress = appItem.progress;
                                var progressDiff = coverFlip.progressMarker2;
                                var translateDiff = -root.width;
                                // progress : progressDiff = translate : translateDiff
                                xTranslate = progress * translateDiff / progressDiff;
                                break;
//                            } else if (appItem.progress < coverFlip.progressMarker2) {
//                                xTranslate = -coverFlip.tileWidth
                            }

                            // Intentionally no break here...
                        default:
                            if (appItem.progress > coverFlip.progressMarker2) {
                                xTranslate = xTranslateEasing.value * xTranslateEasing.period;
                                if (appItem.isSelected) {
                                    var translateDiff = root.width * index + appItem.selectedXTranslation
                                    var progressDiff = appItem.selectedProgress
                                    var progress = progressDiff - (appItem.progress - coverFlip.progressMarker2);
                                    // progress : progressDiff = translate : translateDiff
                                    var newTranslate = progress * translateDiff / progressDiff;

                                    xTranslate = appItem.selectedXTranslation - newTranslate;
                                }
                                break;
                            }
                        }
                        if (!appItem.isSelected) {
                            xTranslate += index * units.dp(4);
                        }

                        return xTranslate;
                    }
//                    Behavior on xTranslation {
//                        id: animatedProgressBehavior
//                        enabled: appItem.progress >= coverFlip.progressMarker1 && appItem.progress <= coverFlip.progressMarker2
//                        SmoothedAnimation {
//                            velocity: 0.5;
//                            duration: UbuntuAnimation.BriskDuration;
//                            easing: UbuntuAnimation.StandardEasing
//                        }
//                    }

                    property real angle: {
                        var newAngle = 0;
                        switch (index) {
                        case 0:
                            if (appItem.progress < coverFlip.progressMarker2) {
                                var progress = appItem.progress;
                                var angleDiff = coverFlip.endAngle;
                                var progressDiff = coverFlip.progressMarker2;
                                // progress : progressDiff = angle : angleDiff
                                newAngle = progress * angleDiff / progressDiff;
                            } else {
                                var progress = appItem.progress - coverFlip.progressMarker2;
                                var angleDiff = coverFlip.endAngle;
                                var progressDiff = 1 - coverFlip.progressMarker2;
                                // progress : progressDiff = angle : angleDiff
                                newAngle = progress * angleDiff / progressDiff;
                                newAngle = Math.min(coverFlip.endAngle, newAngle);
                            }
                            break;
                        case 1:
                            if (appItem.progress < coverFlip.progressMarker2) {
                                var progress = coverFlip.progress;
                                var angleDiff = coverFlip.startAngle;
                                var progressDiff = coverFlip.progressMarker2;
                                // progress : progressDiff = angle : angleDiff
                                var angle = progress * angleDiff / progressDiff;
                                newAngle = coverFlip.startAngle - angle;
                                break;
                            }
                            // Intentionally no break here...
                        default:
                            newAngle = coverFlip.startAngle - (angleEasing.value * angleEasing.period);
                            // make sure we stop at the left screen edge
                            newAngle = Math.max(newAngle, coverFlip.endAngle);

                            if (appItem.isSelected) {
//                                    var selectedAngleTranslate = selectedAngleEasing.value * selectedAngleEasing.period
                                var angleDiff = appItem.selectedAngle
                                var progressDiff = appItem.selectedProgress
                                var progress = progressDiff - (appItem.progress - coverFlip.progressMarker2);
                                // progress : progressDiff = angle : angleDiff
                                var selectedAngleTranslate = progress * angleDiff / progressDiff;

                                newAngle = appItem.selectedAngle - selectedAngleTranslate;
                            }
                        }
                        return newAngle;
                    }

                    property real xScale: {
                        var scale = 1;

                        switch (index) {
                        case 0:
                            if (appItem.progress > coverFlip.progressMarker2) {
                                var scaleDiff = coverFlip.maxScale - 1;
                                var progressDiff = 1.5 - coverFlip.progressMarker2;
                                // progress : progressDiff = scale : scaleDiff
                                scale = 1 - (appItem.progress - coverFlip.progressMarker2) * scaleDiff / progressDiff;
                            }
                            break;
                        case 1:
                            if (appItem.progress < coverFlip.progressMarker2) {
                                var scaleDiff = coverFlip.maxScale - 1
                                var progressDiff = coverFlip.progressMarker2
                                // progress : progressDiff = scale : scaleDiff
                                scale = coverFlip.maxScale - (appItem.progress * scaleDiff / progressDiff);
                                break;
                            }
                            // Intentionally no break
                        default:
                            scale = coverFlip.maxScale - scaleEasing.value * scaleEasing.period;
                            if (appItem.isSelected) {
                                var scaleDiff = -(1 - appItem.selectedXScale)
                                var progressDiff = appItem.selectedProgress
                                var progress = progressDiff - (appItem.progress - coverFlip.progressMarker2);
                                // progress : progressDiff = angle : angleDiff
                                var selectedScaleTranslate = progress * scaleDiff / progressDiff;

                                scale = appItem.selectedXScale - selectedScaleTranslate;
                            }
                        }
                        return Math.min(coverFlip.maxScale, Math.max(coverFlip.minScale, scale));
                    }

                    EasingCurve {
                        id: xTranslateEasing
                        type: EasingCurve.OutQuad
                        period: index * -width
                        progress: appItem.translatedProgress
                    }
                    EasingCurve {
                        id: angleEasing
                        type: EasingCurve.InQuad
                        period: coverFlip.startAngle - coverFlip.endAngle
                        progress: appItem.translatedProgress
                    }
                    EasingCurve {
                        id: scaleEasing
                        type: EasingCurve.Linear
                        period: coverFlip.maxScale - coverFlip.minScale
                        progress: appItem.translatedProgress
                    }

                    transform: [
                        Rotation {
                            origin { x: 0; y: coverFlip.height / 2 }
                            axis { x: 0; y: 1; z: 0 }
                            angle: appItem.angle
                        },
                        Translate {
                            x: appItem.xTranslation
                        },
                        Scale {
                            origin { x: appItem.xTranslation; y: coverFlip.height / 2 }
                            xScale: appItem.xScale
                            yScale: xScale
                        }
                    ]

                    Image {
                        id: dropShadow
                        anchors.fill: appImage
                        anchors.margins: -units.gu(2)
                        source: "graphics/dropshadow.png"
                    }
                    Image {
                        id: appImage
                        anchors { left: parent.left; bottom: parent.bottom }
                        width: root.width
                        source: ApplicationManager.get(index).screenshot
                        scale: 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            appItem.select()
                        }
                    }

                    SequentialAnimation {
                        id: switchToAppAnimation
                        property int targetContentX
                        UbuntuNumberAnimation {
                            target: coverFlickable;
                            property: "contentX";
                            to: switchToAppAnimation.targetContentX;
                            duration: UbuntuAnimation.SnapDuration
                        }
                        ScriptAction {
                            script: {
                                ApplicationManager.focusApplication(ApplicationManager.get(index).appId);
                                appItem.isSelected = false;
                                coverFlip.progress = 0;
                                coverFlickable.passedFirstStage = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
