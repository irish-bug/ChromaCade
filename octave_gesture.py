"""
ChromaCade -- octave encoder gesture debounce.

The EC11 octave encoder free-spins with no end-stops, and single-click
precision isn't realistic for a toddler. Rather than 1 click = 1
octave, this treats a whole burst of same-direction rotation (any
number of clicks) as a single +1/-1 octave step -- the actual
octave-step commit only happens once rotation *pauses*, which is what
distinguishes "done turning" from "still turning." A direction reversal
mid-burst restarts the gesture in the new direction rather than trying
to net the two out.

Pure and hardware-free on purpose: this class only tracks state, it
never touches a clock or a timer. The caller (hardware_poller.py) is
responsible for calling rotate() on each raw encoder step and commit()
once enough real time has passed with no further rotate() calls --
kept separate so this logic is unit-testable without real threading/
sleep.
"""


class OctaveGesture:
    def __init__(self):
        self.direction = None  # 'cw' | 'ccw' | None

    def rotate(self, direction):
        """Record one raw encoder step. Most-recent direction wins on
        a mid-gesture reversal."""
        self.direction = direction

    def commit(self):
        """Call once the pause threshold has elapsed with no further
        rotate() calls. Returns +1, -1, or 0 (nothing pending), and
        resets for the next gesture."""
        if self.direction == "cw":
            result = 1
        elif self.direction == "ccw":
            result = -1
        else:
            result = 0
        self.direction = None
        return result
