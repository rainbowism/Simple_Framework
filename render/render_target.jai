Render_Target :: struct {
    fbo:   GLuint;
    rbo:   GLuint;
    color: GLuint;
}

create_render_target :: () -> Render_Target, bool {
    render_target: Render_Target = ---;

    glGenFramebuffers(1, *render_target.fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, render_target.fbo);
    defer glBindFramebuffer(GL_FRAMEBUFFER, 0);

    glGenTextures(1, *render_target.color);
    glBindTexture(GL_TEXTURE_2D, render_target.color);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx window.size_i.x, xx window.size_i.y, 0, GL_RGBA, GL_FLOAT, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, render_target.color, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    glGenRenderbuffers(1, *render_target.rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, render_target.rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, xx window.size_i.x, xx window.size_i.y);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, render_target.rbo);

    if glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE {
        return render_target, true;
    }

    destroy(render_target);
    return .{}, false;
}

destroy :: (render_target: Render_Target) {
    glDeleteTextures(1, *render_target.color);
    glDeleteRenderbuffers(1, *render_target.rbo);
    glDeleteFramebuffers(1, *render_target.fbo);
}

resize_render_target :: (render_target: Render_Target, width: s32, height: s32) {
    glBindFramebuffer(GL_FRAMEBUFFER, render_target.fbo);
    glBindTexture(GL_TEXTURE_2D, render_target.color);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, render_target.rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, xx width, xx height);
}

draw_render_texture :: (render_target: Render_Target, $additive := false) {
    #if additive {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        defer glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_FRAMEBUFFER].program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, render_target.color);
    render_quad();
    render_ctx.draw_calls += 1;
}
