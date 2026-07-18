import pygame
import numpy as np
import time

class ChromaCadeAudio:
    def __init__(self, sample_rate=44100):
        pygame.mixer.init(frequency=sample_rate, size=-16, channels=2, buffer=512)
        self.sample_rate = sample_rate
        
        # Base frequencies for octave 4
        self.base_freqs = {
            'A': 440.00,
            'B': 493.88,
            'C': 261.63, # C4
            'D': 293.66,
            'E': 329.63,
            'F': 349.23,
            'G': 392.00
        }
        
        self.global_octave = 4
        self.accidental_offset = 0 # 0=natural, -1=flat, 1=sharp
        self.pitch_bend_val = 0.0 # -1.0 to 1.0
        self.volume_ceiling = 0.8
        
        self.playing_channels = {} # note_letter -> (channel, base_freq_for_this_play)
        
        self.font = 0 # 0=sine, can add more later
        
    def _generate_sine(self, freq, duration=1.0):
        # Generate a sine wave array
        t = np.linspace(0, duration, int(self.sample_rate * duration), False)
        wave = np.sin(2 * np.pi * freq * t)
        
        # Apply simple envelope to avoid clicks
        fade_len = int(self.sample_rate * 0.01)
        if len(wave) > fade_len * 2:
            fade_in = np.linspace(0, 1, fade_len)
            fade_out = np.linspace(1, 0, fade_len)
            wave[:fade_len] *= fade_in
            wave[-fade_len:] *= fade_out
            
        # Convert to 16-bit PCM
        audio = (wave * 32767 * self.volume_ceiling).astype(np.int16)
        
        # Duplicate for stereo
        stereo = np.column_stack((audio, audio))
        return pygame.sndarray.make_sound(stereo)

    def calculate_freq(self, note_letter):
        # Calculate target frequency based on octave and accidental
        base_freq = self.base_freqs[note_letter]
        
        # Octave shifting: every octave up doubles frequency, down halves
        octave_diff = self.global_octave - 4
        freq = base_freq * (2 ** octave_diff)
        
        # Accidental shifting: one semitone is 2^(1/12)
        freq = freq * (2 ** (self.accidental_offset / 12.0))
        
        return freq
        
    def apply_pitch_bend_math(self, base_freq, bend_val):
        # bend_val is -1.0 to 1.0. Max bend is 2 semitones
        max_bend_semitones = 2.0
        bend_semitones = bend_val * max_bend_semitones
        bent_freq = base_freq * (2 ** (bend_semitones / 12.0))
        return bent_freq

    def note_on(self, note_letter):
        if note_letter in self.playing_channels:
            self.note_off(note_letter)
            
        base_target_freq = self.calculate_freq(note_letter)
        bent_freq = self.apply_pitch_bend_math(base_target_freq, self.pitch_bend_val)
        
        print(f"Playing {note_letter}: base_freq={base_target_freq:.2f}Hz, bent_freq={bent_freq:.2f}Hz")
        
        sound = self._generate_sine(bent_freq)
        channel = pygame.mixer.find_channel()
        if channel:
            channel.play(sound, loops=-1)
            self.playing_channels[note_letter] = (channel, base_target_freq)

    def note_off(self, note_letter):
        if note_letter in self.playing_channels:
            channel, _ = self.playing_channels[note_letter]
            channel.fadeout(50)
            del self.playing_channels[note_letter]
            print(f"Stopped {note_letter}")

    def set_pitch_bend(self, val):
        self.pitch_bend_val = max(-1.0, min(1.0, val))
        print(f"Pitch bend set to {self.pitch_bend_val:.2f}")
        # Note: Pygame Sound objects cannot be easily pitch-shifted while playing.
        # This logs the math that would be applied to a live synthesizer.
        for note, (channel, base_freq) in self.playing_channels.items():
            bent = self.apply_pitch_bend_math(base_freq, self.pitch_bend_val)
            print(f"  -> {note} would bend to {bent:.2f}Hz")

    def set_accidental(self, val):
        self.accidental_offset = max(-1, min(1, val)) # -1 (flat), 0 (natural), 1 (sharp)
        print(f"Accidental set to {self.accidental_offset}")

    def set_octave(self, val):
        self.global_octave = val
        print(f"Octave set to {val}")
        
    def quit(self):
        pygame.mixer.quit()

if __name__ == "__main__":
    print("Initializing ChromaCade Audio Engine Stub...")
    audio = ChromaCadeAudio()
    
    print("\n--- Testing Note C ---")
    audio.note_on('C')
    time.sleep(1.5)
    
    print("\n--- Testing pitch bend up ---")
    audio.set_pitch_bend(1.0)
    time.sleep(1)
    
    print("\n--- Testing pitch bend down ---")
    audio.set_pitch_bend(-1.0)
    time.sleep(1)
    
    print("\n--- Reset pitch bend ---")
    audio.set_pitch_bend(0.0)
    audio.note_off('C')
    time.sleep(0.5)
    
    print("\n--- Testing sharp (C#) ---")
    audio.set_accidental(1)
    audio.note_on('C')
    time.sleep(1.5)
    audio.note_off('C')
    
    audio.quit()
    print("\nTest complete.")
