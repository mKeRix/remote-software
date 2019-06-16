import QtQuick 2.11
import QtQuick.Controls 2.4

Flickable {
    id: itemFlickable
    property string area

    width: parent.width
    height: parent.height
    maximumFlickVelocity: 6000
    flickDeceleration: 1000
    contentHeight: iconFlow.height < 800 - mainNavigation.height - statusBar.height - miniMediaPlayer.height + bottomGradient.height ? iconFlow.height + 40 : iconFlow.height
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickableDirection: Flickable.VerticalFlick

    Behavior on contentY {
        PropertyAnimation {
            duration: 300
            easing.type: Easing.OutExpo
        }
    }

    ScrollBar.vertical: ScrollBar {
        opacity: 0.5
    }

    Column {
        id: iconFlow
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Component.onCompleted: {
            var hasTitle = false;

            for (var i=0; i<config.areas.length; i++) {
                if (config.areas[i].area == area) {
                    for (var k=0; k<loaded_entities.length; k++) {
                        for (var j=0; j<loaded_components[loaded_entities[k].obj].entities.length; j++) {
                            if (loaded_components[loaded_entities[k].obj].entities[j].area == config.areas[i].area) {
                                hasTitle = true;
                            }
                        }

                        if (k>0) {
                            var spacerObj = Qt.createQmlObject('import QtQuick 2.0; Rectangle {color: colorBackgroundTransparent; width: parent.width; height: 40;}', iconFlow, '')
                        }
                        if (hasTitle) {
                            var roomObj = Qt.createQmlObject('import QtQuick 2.0; Text {color: colorText; font.family: "Open Sans"; font.weight: Font.Normal; font.pixelSize: 60; text: "'+ supported_entities_translation[loaded_entities[k].id] +'";}', iconFlow, "");
                        }
                        hasTitle = false;

                        for (var j=0; j<loaded_components[loaded_entities[k].obj].entities.length; j++) {
                            if (loaded_components[loaded_entities[k].obj].entities[j].area == config.areas[i].area) {
                                // load entity button
                                var comp = Qt.createComponent("qrc:/components/"+ loaded_entities[k].obj +"/ui/Button.qml");
                                if (comp.status != Component.Ready) {
                                    console.debug("Error: " + comp.errorString() );
                                }
                                var obj = comp.createObject(iconFlow, {entityID: j});

                            }
                        }
                    }
                }
            }
        }
    }
}
