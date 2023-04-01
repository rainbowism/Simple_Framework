Render_Target :: struct {
    pass:  sg_pass;
    color: sg_image;
    depth: sg_image;
}

create_render_target :: () -> Render_Target, bool #expand {
    render_target, success := create_render_target(window.size_i.x, window.size_i.y);
    return render_target, success;
}

create_render_target :: (width: s32, height: s32) -> Render_Target, bool {
    render_target: Render_Target = ---;

    offscreen_sample_count := cast(s32) (ifx sg_query_features().msaa_render_targets then 4 else 1);
    target_image_desc := sg_image_desc.{
        render_target = true,
        width  = width,
        height = height,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        sample_count = offscreen_sample_count,
        label = "Render Target Color Image",
    };
    render_target.color = sg_make_image(*target_image_desc);
    target_image_desc.pixel_format = .DEPTH;
    target_image_desc.label = "Render Target Depth Image";
    render_target.depth = sg_make_image(*target_image_desc);
    pass_desc: sg_pass_desc;
    pass_desc.color_attachments[0].image     = render_target.color;
    pass_desc.depth_stencil_attachment.image = render_target.depth;
    pass_desc.label = "Render Target Pass";
    render_target.pass = sg_make_pass(*pass_desc);

    return render_target, true;
}

free :: (using render_target: Render_Target) {
    sg_destroy_pass(pass);
    sg_destroy_image(depth);
    sg_destroy_image(color);
}

rt_pass_begin :: (render_target: Render_Target) #expand {
    sg_begin_pass(render_target.pass, *default_pass_action);
}

rt_pass_begin :: (render_target: Render_Target, pass_action: *sg_pass_action) #expand {
    sg_begin_pass(render_target.pass, pass_action);
}

rt_pass_end :: sg_end_pass;

resize :: (render_target: *Render_Target, width: s32, height: s32) {
    free(render_target);
    << render_target = create_render_target(width,  height);
}
