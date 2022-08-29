load_sound :: (filepath: string, $type := Sound_Type.Effect, channel: *Sound_Channel = null) -> *Sound {
    sound := New(Sound);
    c_filepath := temp_c_string(filepath);
    #if type == .Effect {
        result := ma_sound_init_from_file(
            *audio_ctx.engine,
            c_filepath,
            xx ma_sound_flags.DECODE,
            channel,
            null,
            sound
        );
    } else {
        result := ma_sound_init_from_file(
            *audio_ctx.engine,
            c_filepath,
            xx (ma_sound_flags.STREAM | .NO_SPATIALIZATION),
            channel,
            null,
            sound
        );
    }
    if result != ma_result.SUCCESS {
        free(sound);
        return null;
    }
    return sound;
}

free_sound :: (sound: *Sound) {
    ma_sound_uninit(sound);
}

Sound :: ma_sound;

Sound_Type :: enum {
    Effect;
    Music;
}
