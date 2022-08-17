#module_parameters(DEBUG := false, LOG_LEVEL := LogLevel.INFO, LOG_FILE_PATH := true);

SF_Result :: enum {
    Ok;
    FailedToInitGLFW;
    FailedToCreateWindow;
}

#load "utils.jai";
#load "data.jai";
#load "assets.jai";
#load "window.jai";
#load "audio.jai";

#load "2d/texture.jai";
#load "2d/font.jai";
#load "2d/render.jai";
#load "2d/render_layer.jai";
#load "2d/default_shader.jai";
