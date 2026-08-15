from octave_gesture import OctaveGesture


def test_no_rotation_commits_nothing():
    g = OctaveGesture()
    assert g.commit() == 0


def test_single_cw_click_commits_plus_one():
    g = OctaveGesture()
    g.rotate("cw")
    assert g.commit() == 1


def test_single_ccw_click_commits_minus_one():
    g = OctaveGesture()
    g.rotate("ccw")
    assert g.commit() == -1


def test_many_same_direction_clicks_still_commit_exactly_one_octave():
    g = OctaveGesture()
    for _ in range(50):
        g.rotate("cw")
    assert g.commit() == 1


def test_direction_reversal_mid_gesture_uses_most_recent_direction():
    g = OctaveGesture()
    g.rotate("cw")
    g.rotate("cw")
    g.rotate("ccw")
    assert g.commit() == -1


def test_commit_resets_state_for_next_gesture():
    g = OctaveGesture()
    g.rotate("cw")
    assert g.commit() == 1
    assert g.commit() == 0  # nothing pending after a fresh commit
    g.rotate("ccw")
    assert g.commit() == -1
