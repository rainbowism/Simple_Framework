using miniaudio :: #import "miniaudio" (NO_SSE_41 = Disable_SIMD);

create_sound_channel :: (parent: *Sound_Channel = null) -> *Sound_Channel {
    assert(audio_ctx.init_value == Audio_Init_Value, "Tried to create a sound channel before initializing the audio module.");

    sound_channel := New(Sound_Channel);
    result := ma_sound_group_init(*audio_ctx.engine, 0, parent, sound_channel);
    if result != ma_result.SUCCESS {
        free(sound_channel);
        return null;
    }
    return sound_channel;
}

free_sound_channel :: (sound_channel: *Sound_Channel) #expand {
    free(sound_channel);
}

get_sample_rate :: () -> u32 #expand {
    return ma_engine_get_sample_rate(*audio_ctx.engine);
}

channel_get_volume :: () -> float #expand {
    return ma_node_get_output_bus_volume(ma_node_graph_get_endpoint(*audio_ctx.engine.nodeGraph), 0);
}

channel_get_volume :: (sound_channel: *Sound_Channel) -> float #expand {
    return ma_sound_group_get_volume(sound_channel);
}

channel_set_volume :: (volume: float) -> float #expand {
    ma_engine_set_volume(*audio_ctx.engine, volume);
}

channel_set_volume :: (sound_channel: *Sound_Channel, volume: float) -> float #expand {
    ma_sound_group_set_volume(sound_channel, volume);
}

channel_set_pitch :: (channel: *Sound_Channel, pitch: float) #expand {
    ma_sound_group_set_pitch(channel, pitch);
}

channel_reset_pitch :: (channel: *Sound_Channel) #expand {
    ma_sound_group_set_pitch(channel, 1.0);
}

play_sound :: (sound: *Sound, $restart := true) #expand {
    #if restart  ma_sound_seek_to_pcm_frame(sound, 0);
    ma_sound_start(sound);
}

stop_sound :: (sound: *Sound) #expand {
    ma_sound_stop(sound);
}

Sound_Channel :: ma_sound_group;

#scope_module

audio_init :: () -> SF_Result {
    assert(audio_ctx.init_value != Audio_Init_Value, "Trying to initialize audio module again!");

    ctx_config := ma_context_config_init();
    result     := ma_context_init(null, 0, *ctx_config, *audio_ctx.ma_ctx);
    if result != ma_result.SUCCESS {
        warn(.Audio, "Failed to initialize miniaudio context.");
        return .Failed_To_Init_Miniaudio;
    }

    device_config := ma_device_config_init(.playback);
    device_config.playback.pDeviceID        = null;
    device_config.playback.format           = .f32;
    device_config.playback.channels         = 2;
    device_config.sampleRate                = 48000;
    device_config.dataCallback              = audio_data_callback;
    device_config.pUserData                 = *audio_ctx.engine;
    device_config.performanceProfile        = .low_latency;
    device_config.noPreSilencedOutputBuffer = 0;
    device_config.noClip                    = 0;
    result = ma_device_init(*audio_ctx.ma_ctx, *device_config, *audio_ctx.device);
    if result != ma_result.SUCCESS {
        warn(.Audio, "Failed to initialize miniaudio playback device.");
        return .Failed_To_Init_Miniaudio;
    }

    engine_config := ma_engine_config_init();
    engine_config.pDevice  = *audio_ctx.device;
    engine_config.noDevice = 0;
    result = ma_engine_init(*engine_config, *audio_ctx.engine);
    if result != ma_result.SUCCESS {
        warn(.Audio, "Failed to initialize miniaudio mixing engine.");
        return .Failed_To_Init_Miniaudio;
    }

    audio_ctx.init_value = Audio_Init_Value;

    trace(.Audio, "Audio device initialized successfully:\n  Format: %\n  Channels: %\n  Sample Rate: %",
        to_string(ma_get_format_name(audio_ctx.device.playback.format)),
        audio_ctx.device.playback.channels,
        audio_ctx.device.sampleRate,
    );

    return .Ok;
}

audio_deinit :: () {
    if audio_ctx.init_value != Audio_Init_Value  return;
    ma_device_uninit(*audio_ctx.device);
    ma_engine_uninit(*audio_ctx.engine);
    audio_ctx = Audio_Context.{};
}

audio_ctx: Audio_Context;

Audio_Context :: struct {
    engine: ma_engine;
    device: ma_device;
    ma_ctx: ma_context;

    master_channel: *Sound_Channel;

    init_value: u32;
}

#scope_file

Audio_Init_Value :: 0x28008135;

audio_data_callback :: (device: *ma_device, output: *void, input: *void, frame_count: u32) #c_call {
    engine: *ma_engine = xx device.pUserData;
    ma_engine_read_pcm_frames(engine, output, xx frame_count, null);
}
