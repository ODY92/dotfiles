pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services

Item {
    id: root

    property real radius: 18

    // Tinted translucent glass base (alpha kept well above Hyprland ignore_alpha=0.12 so blur hugs the exact rounded contour)
    Rectangle {
        id: glassBase

        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Colours.palette.m3surface, Colours.light ? 0.56 : 0.44)

        Behavior on color {
            CAnim {}
        }
    }

    // Vertical liquid-glass specular refraction gradient + subtle primary caustic tint at bottom
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(1, 1, 1, Colours.light ? 0.50 : 0.22)
            }
            GradientStop {
                position: 0.14
                color: Qt.rgba(1, 1, 1, Colours.light ? 0.16 : 0.06)
            }
            GradientStop {
                position: 0.55
                color: "transparent"
            }
            GradientStop {
                position: 0.88
                color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.06 : 0.08)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(1, 1, 1, Colours.light ? 0.22 : 0.10)
            }
        }
    }

    // Diagonal glass sheen catchlight (subtle optical curve feel)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(1, 1, 1, Colours.light ? 0.18 : 0.07)
            }
            GradientStop {
                position: 0.35
                color: "transparent"
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(1, 1, 1, Colours.light ? 0.10 : 0.04)
            }
        }
    }

    // Overhead liquid-glass specular rim catchlight along top bezel
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: root.radius * 0.85
        anchors.rightMargin: root.radius * 0.85
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 0.25
                color: Qt.rgba(1, 1, 1, Colours.light ? 0.72 : 0.38)
            }
            GradientStop {
                position: 0.5
                color: Qt.rgba(1, 1, 1, Colours.light ? 0.90 : 0.52)
            }
            GradientStop {
                position: 0.75
                color: Qt.rgba(1, 1, 1, Colours.light ? 0.72 : 0.38)
            }
            GradientStop {
                position: 1.0
                color: "transparent"
            }
        }
    }

    // Inner depth rim tinted with shell primary
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.12 : 0.10)
    }

    // Outer crisp glass rim
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, Colours.light ? 0.65 : 0.24)
    }
}
