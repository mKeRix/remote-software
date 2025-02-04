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
import Haptic 1.0
import StandbyControl 1.0
import ButtonHandler 1.0

import "qrc:/basic_ui" as BasicUI

Item {
    id: main_container
    width: parent.width; height: parent.height
    clip: true
    enabled: loader_main.state === "visible" ? true : false
    layer.enabled: true

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CONNECT TO BUTTONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    Connections {
        target: ButtonHandler
        enabled: loader_main.state === "visible" && StandbyControl.mode === StandbyControl.ON ? true : false

        onButtonPressed: {
            switch (button) {
            case ButtonHandler.DPAD_RIGHT:
                if (loader_main.item.mainNavigationSwipeview.currentIndex < loader_main.item.mainNavigationSwipeview.count-1) {
                    loader_main.item.mainNavigationSwipeview.incrementCurrentIndex();
                } else {
                    Haptic.playEffect(Haptic.Buzz);
                }
                break;
            case ButtonHandler.DPAD_LEFT:
                if (loader_main.item.mainNavigationSwipeview.currentIndex > 0) {
                    loader_main.item.mainNavigationSwipeview.decrementCurrentIndex();
                } else {
                    Haptic.playEffect(Haptic.Buzz);
                }
                break;
            case ButtonHandler.DPAD_UP:
                var newpos = mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentY - 200;
                if (newpos <=0 && mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentY === 0) {
                    Haptic.playEffect(Haptic.Buzz);
                }
                if (newpos <= 0) {
                    newpos = 0;
                }
                mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentY = newpos;
                break;
            case ButtonHandler.DPAD_DOWN:
                newpos = mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentY + 200;
                if (newpos >= (mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentHeight - mainNavigationSwipeview.currentItem.mainNavigationLoader.item._height) && mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentY == (mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentHeight - mainNavigationSwipeview.currentItem.mainNavigationLoader.item._height)) {
                    Haptic.playEffect(Haptic.Buzz);
                }
                if (newpos >= (mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentHeight - mainNavigationSwipeview.currentItem.mainNavigationLoader.item._height)) {
                    newpos = mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentHeight - mainNavigationSwipeview.currentItem.mainNavigationLoader.item._height;
                }
                mainNavigationSwipeview.currentItem.mainNavigationLoader.item._contentY = newpos;
                break;
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // AUTO ROOM SELECTION BASED ON BLUETOOTH TAGS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    Connections {
        target: bluetoothArea
        enabled: config.settings.bluetootharea

        onCurrentAreaChanged: {
            var p = config.pages

            if (mainNavigation.menuConfig[mainNavigation.menuConfig.currentIndex].name !== bluetoothArea.currentArea) {
                for (var i=0; i<p.length; i++) {
                    if (p[i].name === bluetoothArea.currentArea) {
                        mainNavigationSwipeview.currentIndex = i;
                    }
                }
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MAIN CONTAINER CONTENT
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property alias mainNavigationSwipeview: mainNavigationSwipeview
    property int itemsLoaded: 0
    property bool startUp: false
    property bool firstInit: true

    function doneLoading() {
        itemsLoaded = 0;
        if (firstInit) {
            firstInit = false;
            loadingScreen.item.state = "loaded";
            StandbyControl.init();
        } else {
            profileLoadingScreen.hide();
        }
    }

    SwipeView {
        id: mainNavigationSwipeview
        width: parent.width; height: parent.height-miniMediaPlayer.height
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        currentIndex: 0

        Component.onCompleted: {
            if (mainNavigation.menuConfig.count == 0) {
                doneLoading();
            }
        }

        Repeater {
            id: mainNavigationRepeater
            model: mainNavigation.menuConfig

            Loader {
                id: mainNavigationLoader
                asynchronous: true

                property bool _isCurrentItem: SwipeView.isCurrentItem
                property alias mainNavigationLoader: mainNavigationLoader

                function determinePageToLoad(type) {
                    if (type === "favorites") {
                        mainNavigationLoader.source = "qrc:/basic_ui/pages/Favorites.qml";
                    } else if (type === "settings") {
                        mainNavigationLoader.setSource("qrc:/basic_ui/pages/Settings.qml");
                    } else {
                        mainNavigationLoader.setSource("qrc:/basic_ui/pages/Page.qml", { "page": page });
                    }
                }

                Component.onCompleted: {
                        determinePageToLoad(page);
                }

                onStatusChanged: {
                    if (mainNavigationLoader.status == Loader.Ready) {
                        itemsLoaded += 1;
                        console.debug("PAGE LOADED: " + itemsLoaded + "/" + mainNavigation.menuConfig.count);
                        if (itemsLoaded == mainNavigation.menuConfig.count) {
                            console.debug("EVERY PAGE LOADED. " + itemsLoaded);
                            doneLoading();
                        }
                    }
                }
            }
        }

        onCurrentIndexChanged: {
            // change navigation index after startup
            if (mainNavigationSwipeview.count == mainNavigation.menuConfig.count && !startUp) {
                startUp = true
                mainNavigationSwipeview.setCurrentIndex(0);
            }

            if (startUp) {
                mainNavigation.mainNavigationListView.currentIndex = currentIndex;
            }

            if (itemsLoaded >= 3) {
                if (mainNavigation.mainNavigationListView.count !== 0 && !mainNavigation.mainNavigationListView.currentItem && !mainNavigation.mainNavigationListView.currentItem.held) {
                    mainNavigation.mainNavigationListView.currentIndex = currentIndex       ;
                    mainNavigation.mainNavigationListView.positionViewAtIndex(currentIndex, ListView.Center)
                }
            }

            // change the statusbar title
            if (mainNavigation.mainNavigationListView.count !== 0 && mainNavigationSwipeview.currentItem.mainNavigationLoader.item && mainNavigationSwipeview.currentItem.mainNavigationLoader.item.contentY < 130) {
                statusBar.title = "";
            } else if (mainNavigation.mainNavigationListView.count !== 0 && mainNavigationSwipeview.currentItem.mainNavigationLoader.item) {
                statusBar.title = mainNavigationSwipeview.currentItem.mainNavigationLoader.item.title;
            }

            // change statusbar opacity
            if (mainNavigation.mainNavigationListView.count !== 0 && mainNavigationSwipeview.currentItem.mainNavigationLoader.item && mainNavigationSwipeview.currentItem.mainNavigationLoader.item.contentY < 10) {
                statusBar.bg.opacity = 0;
            } else if (mainNavigation.mainNavigationListView.count !== 0 && mainNavigationSwipeview.currentItem.mainNavigationLoader.item) {
                statusBar.bg.opacity = 1;
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MINI MEDIA PLAYER
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property alias miniMediaPlayer: miniMediaPlayer
    Item {
        id: miniMediaPlayer
        width: parent.width; height: 0
        anchors.bottom: parent.bottom

        property alias miniMediaPlayerLoader: miniMediaPlayerLoader

        Loader {
            id: miniMediaPlayerLoader
            active: false
            anchors.fill: parent
        }

        Connections {
            target: entities

            onMediaplayersPlayingChanged: {
                if (!miniMediaPlayerLoader.active && entities.mediaplayersPlaying.length !== 0) {
                    miniMediaPlayer.height = 90;
                    miniMediaPlayerLoader.setSource("qrc:/basic_ui/MiniMediaPlayer.qml")
                    miniMediaPlayerLoader.active = true;
                } else if (miniMediaPlayerLoader.active && entities.mediaplayersPlaying.length === 0) {
                    loader_main.state = "visible";
                    miniMediaPlayer.height = 0;
                    miniMediaPlayer.miniMediaPlayerLoader.active = false;
                    miniMediaPlayer.miniMediaPlayerLoader.source = "";
                }
            }
        }

        Behavior on height {
            NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MAIN NAVIGATION
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property alias mainNavigation: mainNavigation

    BasicUI.MainNavigation {
        id: mainNavigation
        anchors { bottom: miniMediaPlayer.top; horizontalCenter: parent.horizontalCenter }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // STATUS BAR
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    property alias statusBar: statusBar

    BasicUI.StatusBar { id: statusBar }
}
