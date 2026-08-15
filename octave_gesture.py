"""
ChromaCade -- octave encoder gesture debounce.

The EC11 octave encoder free-spins with no end-stops, and single-click
precision isn't realistic for a toddler. Rather than 1 click = 1
octave, this treats a whole burst of same-direction rotation (any
number of clicks) as a single +1/-1 octave step.

Leading-edge debounce: the first rotation event of a new gesture fires
immediately (feels responsive, no perceived lag), and any further
rotation while that gesture is still "live" gets silently absorbed --
so a fast spin still only ever produces one octave step, same
protection as waiting for a pause would give, but without the delay.
A gesture ends (ready to fire again) once the caller confirms enough
real time has passed with no further rotate() calls.

Pure and hardware-free on purpose: this class only tracks state, it
never touches a clock or a timer. The caller (hardware_poller.py) is
responsible for calling rotate() on each raw encoder step and reset()
once a pause threshold has elapsed -- kept separate so this logic is
unit-testable without real threading/sleep.
"""


class OctaveGesture:
    def __init__(self):
        self.active = False

    def rotate(self, direction):
        """Record one raw encoder step. Returns +1, -1, or 0 -- the
        octave delta to apply immediately (0 if a gesture is already
        active and this click was absorbed)."""
        if self.active:
            return 0
        self.active = True
        return 1 if direction == "cw" else -1

    def reset(self):
        """Call once the pause threshold has elapsed with no further
        rotate() calls -- ends the current gesture so the next one
        fires immediately again."""
        self.active = False
