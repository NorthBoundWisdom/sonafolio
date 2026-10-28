from pathlib import Path
import re

from configs import generate_xcodeproj


ROOT = Path(__file__).resolve().parents[2]
CONTROL_KIT = ROOT / "app/Sources/Audio2TextApp/AppControls.swift"
PANELS = [
    path
    for folder in ("Audio2TextApp", "Audio2TextiOS")
    for path in (ROOT / "app/Sources" / folder).glob("*.swift")
    if path != CONTROL_KIT
]


def test_control_kit_is_shared_with_ios():
    assert generate_xcodeproj._is_ios_shared_app_source(CONTROL_KIT)


def test_panels_do_not_define_control_styles_or_native_input_wrappers():
    style = re.compile(r":\s*(?:ButtonStyle|MenuStyle|TextFieldStyle|ToggleStyle|NSViewRepresentable)\b")
    violations = [
        str(path.relative_to(ROOT))
        for path in PANELS
        if style.search(path.read_text(encoding="utf-8"))
    ]
    assert not violations, f"Move control implementations to AppControls.swift: {violations}"


def test_panels_use_shared_control_styles_and_primitives():
    local_style = re.compile(
        r"\.(?:buttonStyle|menuStyle|textFieldStyle|toggleStyle|pickerStyle|controlSize)\(\s*\."
        r"|\b(?:TextEditor|ProgressView|Picker)\("
    )
    violations = [
        f"{path.relative_to(ROOT)}:{number}"
        for path in PANELS
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1)
        if local_style.search(line)
    ]
    assert not violations, f"Use the shared control kit instead of panel-specific styles: {violations}"
