import pytest

from sound_pools import Cycler, _list_wav_files, _require_file


def test_cycler_returns_items_in_order():
    c = Cycler(["a", "b", "c"])
    assert [c.next(), c.next(), c.next()] == ["a", "b", "c"]


def test_cycler_wraps_around():
    c = Cycler(["a", "b"])
    c.next()
    c.next()
    assert c.next() == "a"


def test_cycler_rejects_empty_list():
    with pytest.raises(ValueError):
        Cycler([])


def test_cycler_single_item_always_returns_it():
    c = Cycler(["only"])
    assert [c.next(), c.next(), c.next()] == ["only", "only", "only"]


def test_list_wav_files_only_wavs(tmp_path):
    (tmp_path / "a.wav").write_bytes(b"")
    (tmp_path / "b.wav").write_bytes(b"")
    (tmp_path / "notes.txt").write_bytes(b"")
    assert _list_wav_files(str(tmp_path)) == ["a.wav", "b.wav"]


def test_list_wav_files_excludes_named_files(tmp_path):
    (tmp_path / "a.wav").write_bytes(b"")
    (tmp_path / "startover.wav").write_bytes(b"")
    (tmp_path / "tryagain.wav").write_bytes(b"")
    result = _list_wav_files(str(tmp_path), exclude={"startover.wav", "tryagain.wav"})
    assert result == ["a.wav"]


def test_list_wav_files_empty_directory(tmp_path):
    assert _list_wav_files(str(tmp_path)) == []


def test_require_file_returns_path_when_present(tmp_path):
    f = tmp_path / "keepgoing.wav"
    f.write_bytes(b"")
    assert _require_file(str(f)) == str(f)


def test_require_file_raises_when_missing(tmp_path):
    with pytest.raises(FileNotFoundError):
        _require_file(str(tmp_path / "keepgoing.wav"))
