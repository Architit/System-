# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_channel_script_contains_expected_commands():
    text = (REPO_ROOT / "CHANNEL_CORE/system_channel.py").read_text(encoding="utf-8")
    assert "/status" in text
    assert "/sync" in text
    assert "/exit" in text
    assert "TelegramClient" in text
    assert "events.NewMessage" in text


def test_channel_script_has_entrypoint():
    text = (REPO_ROOT / "CHANNEL_CORE/system_channel.py").read_text(encoding="utf-8")
    assert "def main():" in text
    assert 'if __name__ == "__main__":' in text
