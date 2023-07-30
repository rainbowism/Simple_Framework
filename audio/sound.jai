load_sound :: (filepath: string, channel: *Sound_Channel = null, $type := Sound_Type.Effect) -> *Sound {
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

load_sound :: (destination: *Sound, filepath: string, channel: *Sound_Channel = null, $type := Sound_Type.Effect) -> bool {
    c_filepath := temp_c_string(filepath);
    #if type == .Effect {
        result := ma_sound_init_from_file(
            *audio_ctx.engine,
            c_filepath,
            xx ma_sound_flags.DECODE,
            channel,
            null,
            destination
        );
    } else {
        result := ma_sound_init_from_file(
            *audio_ctx.engine,
            c_filepath,
            xx (ma_sound_flags.STREAM | .NO_SPATIALIZATION),
            channel,
            null,
            destination
        );
    }
    if result != ma_result.SUCCESS {
        return false;
    }
    return true;
}

copy_sound :: (destination: *Sound, existing: *Sound, channel: *Sound_Channel = null) {
    ma_sound_init_copy(*audio_ctx.engine, existing, xx ma_sound_flags.DECODE, channel, destination);
}

free_sound :: (sound: *Sound) {
    ma_sound_uninit(sound);
}

get_length_in_frames :: inline (sound: *Sound) -> s64 {
    value: u64 = ---;
    ma_data_source_get_length_in_pcm_frames(sound.pDataSource, *value);
    return cast,no_check(s64) value;
}

get_cursor_in_frames :: inline (sound: *Sound) -> s64 {
    value: u64 = ---;
    ma_data_source_get_cursor_in_pcm_frames(sound.pDataSource, *value);
    return cast,no_check(s64) value;
}

get_length_in_seconds :: inline (sound: *Sound) -> float {
    value: float = ---;
    ma_data_source_get_length_in_seconds(sound.pDataSource, *value);
    return value;
}

get_cursor_in_seconds :: inline (sound: *Sound) -> float {
    value: float = ---;
    ma_data_source_get_cursor_in_seconds(sound.pDataSource, *value);
    return value;
}

get_volume :: (sound: *Sound) -> float {
    value: float = ---;
    ma_sound_get_volume(sound, *value);
    return value;
}

set_volume :: (sound: *Sound, volume: float) {
    ma_sound_set_volume(sound, volume);
}

set_pitch :: (sound: *Sound, pitch: float) {
    ma_sound_set_pitch(sound, pitch);
}

reset_pitch :: (sound: *Sound) {
    ma_sound_set_pitch(sound, 1.0);
}

Sound :: ma_sound;

Sound_Type :: enum {
    Effect;
    Music;
}
