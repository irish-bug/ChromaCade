from octave_gesture import OctaveGesture


def test_first_cw_click_fires_plus_one_immediately():
    g = OctaveGesture()
    assert g.rotate("cw") == 1


def test_first_ccw_click_fires_minus_one_immediately():
    g = OctaveGesture()
    assert g.rotate("ccw") == -1


def test_further_clicks_in_same_gesture_are_absorbed():
    g = OctaveGesture()
    assert g.rotate("cw") == 1
    assert g.rotate("cw") == 0
    assert g.rotate("cw") == 0


def test_many_clicks_in_one_burst_still_only_fire_once():
    g = OctaveGesture()
    results = [g.rotate("cw") for _ in range(50)]
    assert results[0] == 1
    assert all(r == 0 for r in results[1:])


def test_direction_reversal_mid_gesture_is_absorbed_not_fired():
    g = OctaveGesture()
    assert g.rotate("cw") == 1
    assert g.rotate("ccw") == 0  # gesture already active, absorbed


def test_reset_allows_the_next_gesture_to_fire_immediately():
    g = OctaveGesture()
    assert g.rotate("cw") == 1
    assert g.rotate("cw") == 0
    g.reset()
    assert g.rotate("ccw") == -1
