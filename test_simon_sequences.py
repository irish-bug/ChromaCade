import random

import pytest

from simon_sequences import (
    FAMOUS_NUMBERS,
    SimonSession,
    digit_to_letter,
    digits_of,
    pool_source,
    random_source,
    sequence_from_number,
)


def test_digits_of_strips_decimal_point():
    assert digits_of("3.14159") == [3, 1, 4, 1, 5, 9]


def test_digit_to_letter_zero_is_c():
    assert digit_to_letter(0) == "C"


def test_digit_to_letter_six_is_b():
    assert digit_to_letter(6) == "B"


def test_digit_to_letter_wraps_at_seven():
    assert digit_to_letter(7) == "C"
    assert digit_to_letter(9) == "E"


def test_sequence_from_number_matches_worked_example():
    # 3.14159 -> F D G D A E, per the exact example this was designed against
    assert sequence_from_number("3.14159") == ["F", "D", "G", "D", "A", "E"]


@pytest.mark.parametrize("name", list(FAMOUS_NUMBERS.keys()))
def test_famous_numbers_produce_nonempty_sequences(name):
    assert len(sequence_from_number(FAMOUS_NUMBERS[name])) > 5


def test_pool_source_rejects_empty_pool():
    with pytest.raises(ValueError):
        pool_source([])


def test_pool_source_next_letter_looks_up_pool():
    next_letter, max_length = pool_source(["C", "D", "E"])
    assert max_length == 3
    assert next_letter(0) == "C"
    assert next_letter(2) == "E"


def test_random_source_is_seedable_and_deterministic():
    next_letter, max_length = random_source(rng=random.Random(42))
    assert max_length is None
    first = next_letter(0)
    next_letter2, _ = random_source(rng=random.Random(42))
    assert next_letter2(0) == first


# --- SimonSession, driven by a fixed pool (song/number-style source) ---


def make_pool_session(pool=("C", "D", "E")):
    next_letter, max_length = pool_source(list(pool))
    return SimonSession(next_letter, max_length)


def test_session_starts_at_round_one():
    session = make_pool_session()
    assert session.round_number == 1
    assert session.sequence == ["C"]
    assert not session.complete


def test_correct_full_round_grows_sequence():
    session = make_pool_session()
    result = session.press("C")
    assert result == "round_complete"
    assert session.round_number == 2
    assert session.sequence == ["C", "D"]


def test_continue_mid_round():
    session = make_pool_session()
    session.press("C")  # round 1 -> now round 2, sequence ["C","D"]
    result = session.press("C")
    assert result == "continue"
    assert session.input_index == 1


def test_wrong_press_does_not_grow_or_advance():
    session = make_pool_session()
    result = session.press("G")
    assert result == "wrong"
    assert session.sequence == ["C"]
    assert session.input_index == 0


def test_finite_source_completes_when_exhausted():
    session = make_pool_session(pool=["C", "D"])
    session.press("C")  # round 1 done -> round 2, sequence ["C","D"]
    result = session.press("C")
    assert result == "continue"
    result = session.press("D")
    assert result == "complete"
    assert session.complete


def test_press_after_complete_returns_already_complete():
    session = make_pool_session(pool=["C"])
    result = session.press("C")
    assert result == "complete"
    assert session.press("C") == "already_complete"


def test_reset_returns_to_round_one():
    session = make_pool_session()
    session.press("C")
    session.press("C")
    session.press("D")
    assert session.round_number == 3
    session.reset()
    assert session.round_number == 1
    assert session.sequence == ["C"]
    assert not session.complete
    assert session.input_index == 0


def test_reset_after_complete_starts_a_fresh_finite_game():
    session = make_pool_session(pool=["C"])
    session.press("C")
    assert session.complete
    session.reset()
    assert not session.complete
    assert session.sequence == ["C"]


# --- SimonSession, driven by the random source ---


def test_random_source_session_never_completes():
    next_letter, max_length = random_source(rng=random.Random(1))
    session = SimonSession(next_letter, max_length)
    for _ in range(10):
        # each round replays the whole sequence-so-far from the start
        for letter in list(session.sequence):
            session.press(letter)
    assert not session.complete
    assert session.round_number == 11


def test_random_source_session_grows_by_one_each_round():
    next_letter, max_length = random_source(rng=random.Random(7))
    session = SimonSession(next_letter, max_length)
    assert session.round_number == 1
    session.press(session.sequence[0])
    assert session.round_number == 2
