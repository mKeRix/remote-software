/******************************************************************************
 *
 * Copyright (C) 2018-2019 Marton Borzak <hello@martonborzak.com>
 *
 * This file is part of the YIO-Remote software project.
 *
 * YIO-Remote software is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * YIO-Remote software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with YIO-Remote software. If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *****************************************************************************/

import QtQuick 2.11
import QtQuick.Controls 2.5
import QtQuick.VirtualKeyboard 2.2
import QtQuick.VirtualKeyboard.Settings 2.2

import Style 1.0

import Launcher 1.0
import JsonFile 1.0
import Battery 1.0
import DisplayControl 1.0
import Proximity 1.0
import StandbyControl 1.0

import "qrc:/basic_ui" as BasicUI // TODO: can this be done in a singleton?

ApplicationWindow {
    id: applicationWindow
    objectName : "applicationWindow"


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MAIN WINDOW PROPERTIES
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    visible: true
    width: Style.screen.width
    height: Style.screen.height
    color: Style.color.background

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // UI VARIABLES
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    property bool remoteConfigEnabled: false
    property bool initialSetup: true

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TRANSLATIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property var translations: translationsJson.read()

    JsonFile {
        id: translationsJson
        name: appPath + "/translations.json"
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOCALE
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property var countries: countriesJson.read()

    JsonFile {
        id: countriesJson
        name: appPath + "/locale.json"
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CONFIGURATION
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    Component.onCompleted: {
        console.debug("UI loading");
        console.debug("Resolution: " + Style.screen.width + "x" + Style.screen.height);
        console.debug("Pixel density: " + Style.screen.pixelDensity);
        // TODO(mze) Does the initialization need to be here? Better located in hardware factory.
        //           Or is there some magic sauce calling the setter if config.settings.proximity changed?
        //           This can be done by connecting to a signal of the config in the hardware factory
        Proximity.proximitySetting = Qt.binding(function() { return config.settings.proximity })
        VirtualKeyboardSettings.locale = Qt.binding(function() { return config.settings.language })

        // load bluetooth
        bluetoothArea.init(config.config);
        if (config.settings.bluetootharea) {
            bluetoothArea.startScan();
        }

        // Start websocket API
        api.start();

        // load the integrations if it's not the first time setup
        if (fileio.exists("/firstrun")) {
            console.debug("Starting first time setup");
            loader_main.setSource("qrc:/setup/Setup.qml");
            translateHandler.selectLanguage(config.settings.language);
        } else {
            integrations.load();
        }
    }

    // load the entities when the integrations are loaded
    Connections {
        target: integrations

        onLoadComplete: {
            console.debug("Integrations are loaded.");
            entities.load();

            // set the language
            translateHandler.selectLanguage(config.settings.language);
        }
    }

    Connections {
        target: entities

        onEntitiesLoaded: {
            console.debug("Entities are loaded.");

            // when everything is loaded, load the main UI
            loader_main.setSource("qrc:/MainContainer.qml");

            // if it's the default profile and no pages, load setings screeen
            if (config.getProfile(config.profileId).name === "Default" && config.getProfilePages().length === 0) {
                loader_second.setSource("qrc:/basic_ui/InitialSetup.qml");
                loader_second.active = true;

                // turn on the webconfigurator
                webserver.startService();
                remoteConfigEnabled = true;
            }
        }
    }

    Connections {
        target: config
        enabled: initialSetup

        function turnOffWelcomeScreen() {
            if (initialSetup) {
                initialSetup = false;
                loader_second.setSource("");
                loader_second.active = false;
            }
        }

        onProfilesChanged: { turnOffWelcomeScreen() }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // QML GUI STUFF
    // The main container holds almost all the GUI elements. The secondary container is used to load the buttons into, with their open state.

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MAIN CONTAINER
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    Loader {
        id: loader_main
        asynchronous: true
        width: 480; height: 800
        x: 0; y: 0
        active: false
        state: "visible"
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM

        transform: Scale {
            id: scale
            origin.x: loader_main.width/2; origin.y: loader_main.height/2
        }

        states: [
            State { name: "hidden"; PropertyChanges {target: loader_main; y: -60; scale: 0.8; opacity: 0.4}},
            State { name: "visible"; PropertyChanges {target: loader_main; scale: 1; opacity: 1}}
        ]
        transitions: [
            Transition {to: "hidden"; PropertyAnimation { target: loader_main; properties: "y, scale, opacity"; easing.type: Easing.OutExpo; duration: 800 }},
            Transition {to: "visible"; PropertyAnimation { target: loader_main; properties: "y, scale, opacity"; easing.type: Easing.OutExpo; duration: 500 }}
        ]
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // SECONDARY CONTAINER
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property alias loader_second: loader_second

    Loader {
        id: loader_second
        objectName : "loader_second"
        width: 480; height: 800
        x: 0; y: 0
        asynchronous: true
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
    }

    property alias contentWrapper: contentWrapper

    Item {
        id: contentWrapper
        width: 480; height: 800
        x: 0; y: 0
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VOLUME
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property alias volume: volume

    BasicUI.Volume {
        id: volume
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CHARING SCREEN
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Visible when charging

    property alias chargingScreen: chargingScreen
    Loader {
        id: chargingScreen
        width: 480; height: 800
        x: 0; y: 0
        asynchronous: true
        source: "qrc:/basic_ui/ChargingScreen.qml"
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOW BATTERY POPUP NOTIFICAITON
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Pops up when battery level is under 20%
    Connections {
        target: Battery

        onLowBattery: {
            StandbyControl.wakeup();
            lowBatteryNotification.item.open();

            // signal with the dock that it is low battery
            var obj = integrations.get(config.settings.paired_dock);
            obj.onLowBattery();
        }
    }

    Loader {
        id: lowBatteryNotification
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
        width: 480; height: 800
        x: 0; y: 0
        asynchronous: true
        source: "qrc:/basic_ui/PopupLowBattery.qml"
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // NOTIFICATIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TODO: can this be done in c++?
    function showNotification(data) {
        var comp = Qt.createComponent("qrc:/basic_ui/Notification.qml");
        var obj = comp.createObject(notificationsRow, {type: data.error, text: data.text, actionlabel: data.actionlabel, action: data.action, timestamp: data.timestamp, idN: data.id, _state: "visible"});
    }

    Column {
        objectName: "notificationsRow"
        id: notificationsRow
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
        anchors.fill: parent
        spacing: 10
        topPadding: 20
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // NOTIFICATION DRAWER
    //////////////////////////////////////////////////////////////////////////////////////////////////
    Drawer {
        id: notificationsDrawer
        width: parent.width; height: notifications.list.length > 5 ? 100 + 5 * 104 : 100 + (notifications.list.length + 1) * 104
        edge: Qt.TopEdge
        dragMargin: 20
        interactive: loader_main.state == "visible" ? true : false
        dim: false
        opacity: position

        background: Item { x: parent.width - 1; width: parent.width; height: parent.height }

        onOpacityChanged: {
            loader_main.item.opacity = 1 - opacity + 0.3
        }

        Rectangle {
            width: parent.width; height: parent.height - 40
            y: 40
            color: Style.color.background
        }

        onOpened: {
            loader_main.item.opacity = 0.3
        }

        onClosed: {
            loader_main.item.opacity = 1
        }

        Loader {
            width: parent.width; height: parent.height

            asynchronous: true
            active: notificationsDrawer.position > 0 ? true : false
            source: notificationsDrawer.position > 0 ? "qrc:/basic_ui/NotificationDrawer.qml" : ""
        }

        Connections {
            target: notifications

            onListIsEmpty: {
                notificationsDrawer.close();
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOADING SCREEN
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property alias loadingScreen: loadingScreen
    Loader {
        id: loadingScreen
        objectName: "loadingScreen"
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
        width: parent.width; height: parent.height

        asynchronous: true
        active: true
        source: "qrc:/basic_ui/LoadingScreen.qml"
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PROFILE LOADING SCREEN
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property alias profileLoadingScreen: profileLoadingScreen
    Loader {
        id: profileLoadingScreen
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
        width: parent.width; height: parent.height

        asynchronous: true
        active: false

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
        }

        function show() {
            profileLoadingScreen.setSource("qrc:/basic_ui/ProfileLoading.qml");
            profileLoadingScreen.active = true;
            profileLoadingScreen.opacity = 1;
        }

        function hide() {
            profileLoadingScreenTimer.start();
        }

        Timer {
            id: profileLoadingScreenTimer
            repeat: false
            interval: 400
            running: false

            onTriggered: {
                profileLoadingScreen.opacity = 0;
                profileLoadingScreen.setSource("");
                profileLoadingScreen.active = false;
            }
        }

    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CONFIG ERROR SCREEN
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    Loader {
        width: 480; height: 800
        x: 0; y: 0
        asynchronous: true
        source: "qrc:/basic_ui/ConfigError.qml"
        visible: configError
        active: configError
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // STANDBY MODE TOUCHEVENT OVERLAY
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // captures all touch events when in standby mode. Avoids clicking on random buttons when waking up the display
    property alias touchEventCatcher: touchEventCatcher

    MouseArea {
        id: touchEventCatcher
        objectName: "touchEventCatcher"
        anchors.fill: parent
        enabled: false
        pressAndHoldInterval: 5000

        onPressAndHold: {
            console.debug("Disabling touch even catcher");

            touchEventCatcher.enabled = false;
            DisplayControl.setMode(DisplayControl.StandbyOff);
            if (config.settings.autobrightness) {
                DisplayControl.setBrightness(DisplayControl.ambientBrightness());
            } else {
                DisplayControl.setBrightness(DisplayControl.userBrightness());
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // KEYBOARD
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    InputPanel {
        id: inputPanel
        visible: StandbyControl.mode == StandbyControl.ON || StandbyControl.mode == StandbyControl.DIM
        width: parent.width
        y: applicationWindow.height

        states: State {
            name: "visible"
            when: inputPanel.active
            PropertyChanges {
                target: inputPanel
                y: applicationWindow.height - inputPanel.height
            }
        }
        transitions: Transition {
            id: inputPanelTransition
            from: ""; to: "visible"
            reversible: true
            ParallelAnimation {
                NumberAnimation {
                    properties: "y"
                    duration: 300
                    easing.type: Easing.InOutExpo
                }
            }
        }
    }
}
