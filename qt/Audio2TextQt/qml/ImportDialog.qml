import QtQuick
import QtQuick.Controls as QQC
import GeoControls 1.0
import QtQuick.Layouts

CustomDialog {
    id: root
    title: "Import"
    modal: true
    width: 620
    height: 430
    standardButtons: QQC.Dialog.NoButton

    property string selectedMode: "xiaoyuzhou"

    CustomFileDialog {
        id: localFileDialog
        title: "Local audio"
        onAccepted: localPath.text = selectedFile
    }

    ColumnLayout {
        objectName: "importDialogBody"
        anchors.fill: parent
        spacing: 12

        CustomTabBar {
            id: importTabs
            Layout.fillWidth: true
            onTargetIndexChanged: root.selectedMode = ["xiaoyuzhou", "local"][targetIndex]
            CustomTabButton {
                text: "Xiaoyuzhou"
                tabBar: importTabs
                targetIndex: 0
            }
            CustomTabButton {
                objectName: "localImportTab"
                text: "Local File"
                tabBar: importTabs
                targetIndex: 1
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.selectedMode === "xiaoyuzhou" ? 0 : 1

            ColumnLayout {
                spacing: 10
                CustomTextField {
                    id: episodeUrl
                    alignRightWhenFocused: false
                    placeholderText: "Episode URL"
                    Layout.fillWidth: true
                }
                CustomComboBox {
                    id: importGroup
                    editable: true
                    model: libraryController.groups
                    textRole: "title"
                    Layout.fillWidth: true
                }
                CustomCheckBox {
                    id: downloadAudio
                    text: "Download audio"
                    checked: true
                }
            }

            ColumnLayout {
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    CustomTextField {
                        id: localPath
                        alignRightWhenFocused: false
                        placeholderText: "Audio file"
                        Layout.fillWidth: true
                    }
                    CustomButton {
                        text: "Browse"
                        onClicked: localFileDialog.open()
                    }
                }
                CustomLabel {
                    text: "Local files are transcribed through the same atot service and published into the configured library."
                    color: Theme.placeholderTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item {
                Layout.fillWidth: true
            }
            CustomButton {
                text: "Cancel"
                onClicked: root.close()
            }
            CustomButton {
                text: "Run"
                highlighted: true
                enabled: !jobController.running
                onClicked: {
                    if (root.selectedMode === "xiaoyuzhou") {
                        jobController.importXiaoyuzhou(episodeUrl.text, importGroup.editText || importGroup.currentText, downloadAudio.checked);
                    } else {
                        jobController.transcribeAudio(localPath.text);
                    }
                    root.close();
                }
            }
        }
    }
}
