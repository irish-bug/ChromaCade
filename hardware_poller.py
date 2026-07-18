import time

try:
    import RPi.GPIO as GPIO
    import board
    import busio
    import adafruit_ads1x15.ads1115 as ADS
    from adafruit_ads1x15.analog_in import AnalogIn
    IS_PI = True
except ImportError:
    IS_PI = False
    print("Hardware libraries (RPi.GPIO, adafruit-circuitpython-ads1x15) not found.")
    print("Running in Mock Mode for laptop testing.")

# --- BCM Pin Definitions (from gpio-pin-assignments.md) ---
NOTES = {
    'A': 4,
    'B': 17,
    'C': 27,
    'D': 22,
    'E': 10,
    'F': 9,
    'G': 11
}

OCTAVE_ENC_A = 5
OCTAVE_ENC_B = 6
OCTAVE_BTN = 13

FONT_ENC_A = 26
FONT_ENC_B = 16
FONT_BTN = 20

ROCKER_FLAT = 23
ROCKER_SHARP = 24

DEBOUNCE_TIME = 0.05 # 50ms software debounce

class HardwarePoller:
    def __init__(self, callbacks):
        """
        callbacks is a dict of functions:
        - note_on(letter)
        - note_off(letter)
        - accidental_change(val) # -1, 0, 1
        - octave_change(delta) # -1, 1
        - pitch_bend_update(val) # -1.0 to 1.0
        """
        self.callbacks = callbacks
        self.last_state = {}
        self.last_time = {}
        
        # Encoder states
        self.octave_enc_last = 0
        self.font_enc_last = 0
        
        # ADS1115 for Joystick (pitch bend) and Volume pot
        self.i2c = None
        self.ads = None
        self.joystick_chan = None
        self.volume_chan = None
        
        self.setup_hardware()
        
    def setup_hardware(self):
        if not IS_PI:
            return
            
        # Setup GPIO Pins
        GPIO.setmode(GPIO.BCM)
        
        # Setup Note buttons (active-low with internal pull-ups)
        for pin in NOTES.values():
            GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            self.last_state[pin] = GPIO.HIGH
            self.last_time[pin] = 0
            
        # Setup Encoders & Buttons
        for pin in [OCTAVE_ENC_A, OCTAVE_ENC_B, OCTAVE_BTN, FONT_ENC_A, FONT_ENC_B, FONT_BTN]:
            GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            self.last_state[pin] = GPIO.HIGH
            self.last_time[pin] = 0
            
        # Setup Rocker switch
        for pin in [ROCKER_FLAT, ROCKER_SHARP]:
            GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            self.last_state[pin] = GPIO.HIGH
            self.last_time[pin] = 0

        # Initial encoder state read
        self.octave_enc_last = (GPIO.input(OCTAVE_ENC_A) << 1) | GPIO.input(OCTAVE_ENC_B)
        self.font_enc_last = (GPIO.input(FONT_ENC_A) << 1) | GPIO.input(FONT_ENC_B)
        
        # Setup I2C ADC (ADS1115)
        try:
            self.i2c = busio.I2C(board.SCL, board.SDA)
            self.ads = ADS.ADS1115(self.i2c)
            # Assuming joystick is on channel 0, volume on channel 1
            self.joystick_chan = AnalogIn(self.ads, ADS.P0)
            self.volume_chan = AnalogIn(self.ads, ADS.P1)
        except Exception as e:
            print(f"Failed to init ADS1115: {e}")
            self.ads = None
            
    def _read_pin(self, pin):
        if IS_PI:
            return GPIO.input(pin)
        return 1 # Mock HIGH (unpressed)
        
    def poll(self):
        """Called in a tight loop to read hardware state."""
        now = time.time()
        
        if not IS_PI:
            # We are in mock mode. Real GPIO reading is skipped.
            # In a full simulator, we could poll pygame keyboard events here.
            return

        # 1. Poll Note Buttons with Debounce
        for note, pin in NOTES.items():
            current_state = self._read_pin(pin)
            if current_state != self.last_state[pin]:
                if (now - self.last_time[pin]) > DEBOUNCE_TIME:
                    self.last_state[pin] = current_state
                    self.last_time[pin] = now
                    if current_state == GPIO.LOW: # Pressed
                        if 'note_on' in self.callbacks: self.callbacks['note_on'](note)
                    else: # Released
                        if 'note_off' in self.callbacks: self.callbacks['note_off'](note)
                            
        # 2. Poll Accidental Rocker Switch (no debounce needed for simple state read, but could add it)
        flat_state = self._read_pin(ROCKER_FLAT)
        sharp_state = self._read_pin(ROCKER_SHARP)
        accidental = 0
        if flat_state == GPIO.LOW:
            accidental = -1
        elif sharp_state == GPIO.LOW:
            accidental = 1
            
        if 'accidental_change' in self.callbacks:
            self.callbacks['accidental_change'](accidental)
            
        # 3. Poll Octave Encoder (simple state machine for quadrature reading)
        oct_a = self._read_pin(OCTAVE_ENC_A)
        oct_b = self._read_pin(OCTAVE_ENC_B)
        oct_state = (oct_a << 1) | oct_b
        if oct_state != self.octave_enc_last:
            # Basic quadrature direction check
            if self.octave_enc_last == 0b00 and oct_state == 0b01:
                if 'octave_change' in self.callbacks: self.callbacks['octave_change'](1)
            elif self.octave_enc_last == 0b00 and oct_state == 0b10:
                if 'octave_change' in self.callbacks: self.callbacks['octave_change'](-1)
            self.octave_enc_last = oct_state
            
        # 4. Poll Joystick via ADC
        if self.ads and self.joystick_chan:
            # Convert voltage to a -1.0 to 1.0 range based on joystick center voltage (approx 1.65V on a 3.3V system)
            voltage = self.joystick_chan.voltage
            bend_val = (voltage - 1.65) / 1.65
            # Clamp and add a small deadzone
            bend_val = max(-1.0, min(1.0, bend_val))
            if abs(bend_val) < 0.05: bend_val = 0.0
            if 'pitch_bend_update' in self.callbacks:
                self.callbacks['pitch_bend_update'](bend_val)

    def cleanup(self):
        if IS_PI:
            GPIO.cleanup()

if __name__ == "__main__":
    def note_on(note): print(f"Note ON: {note}")
    def note_off(note): print(f"Note OFF: {note}")
    def accidental_change(val): print(f"Accidental state: {val}")
    def octave_change(delta): print(f"Octave change: {delta}")
    def pitch_bend_update(val): print(f"Pitch Bend: {val:.2f}")
    
    callbacks = {
        'note_on': note_on,
        'note_off': note_off,
        'accidental_change': accidental_change,
        'octave_change': octave_change,
        'pitch_bend_update': pitch_bend_update
    }
    
    print("Starting Hardware Poller Test...")
    poller = HardwarePoller(callbacks)
    try:
        start = time.time()
        while time.time() - start < 5:
            poller.poll()
            time.sleep(0.01) # 10ms loop (100Hz)
    except KeyboardInterrupt:
        pass
    finally:
        poller.cleanup()
        print("Done.")
