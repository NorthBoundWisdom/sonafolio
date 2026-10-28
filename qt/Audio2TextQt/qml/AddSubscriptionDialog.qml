import QtQuick
import QtQuick.Controls as QQC
import GeoControls 1.0
import QtQuick.Layouts

// Mirrors app/Sources/Audio2TextApp/AddSubscriptionSheet.swift.
CustomDialog {
    id: root
    objectName: "addSubscriptionDialog"
    title: "Add Subscription"
    modal: true
    parent: QQC.Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(480, parent.width - 40)
    standardButtons: QQC.Dialog.NoButton

    readonly property int fetchLimit: 10
    readonly property bool canSubmit: urlField.text.trim().length > 0 && !jobController.running

    function submit() {
        if (!canSubmit)
            return;
        jobController.addSubscription(urlField.text.trim(), groupField.editText || groupField.currentText, fetchLimit);
        close();
    }

    onOpened: {
        urlField.text = "";
        urlField.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        ColumnLayout {
            spacing: 6
            Layout.fillWidth: true
            CustomLabel {
                text: "Podcast or RSS URL"
                color: Theme.placeholderTextColor
                font.pixelSize: 12
            }
            CustomTextField {
                id: urlField
                objectName: "addSubscriptionUrl"
                alignRightWhenFocused: false
                placeholderText: "Xiaoyuzhou, Apple Podcast, or RSS URL"
                Layout.fillWidth: true
                onAccepted: root.submit()
            }
        }

        RowLayout {
            spacing: 10
            Layout.fillWidth: true
            CustomLabel {
                text: "Group"
                color: Theme.placeholderTextColor
                font.pixelSize: 12
            }
            CustomComboBox {
                id: groupField
                objectName: "addSubscriptionGroup"
                editable: true
                model: libraryController.groups
                textRole: "title"
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: 10
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            CustomButton {
                text: "Cancel"
                onClicked: root.close()
            }
            CustomButton {
                objectName: "addSubscriptionButton"
                text: "+  Add"
                highlighted: true
                enabled: root.canSubmit
                onClicked: root.submit()
            }
        }
    }
}
