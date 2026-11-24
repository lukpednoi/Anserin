import QtQuick
import "../../"

// Polyphonic stereo-panned Liquid Mercury + Plucked Harp EQ Audio Engine (B · Harp)
// Routed through Anserin's native Sounds (anserin-core) engine so mute/volume settings apply automatically.
QtObject {
    id: audio

    function playSweepBed() {
        Sounds.playSfx("musicpopup/eq/eq_sweep_bed.wav", 0.62);
    }

    function playBand(bandIdx, dir) {
        if (bandIdx < 0 || bandIdx > 9) return;
        if (dir > 0) {
            Sounds.playSfx("musicpopup/eq/harp_up_" + bandIdx + ".wav", 0.90);
        } else if (dir < 0) {
            Sounds.playSfx("musicpopup/eq/harp_dn_" + bandIdx + ".wav", 0.90);
        } else {
            Sounds.playSfx("musicpopup/eq/harp_still_" + bandIdx + ".wav", 0.72);
        }
    }
}
