#import "GL";
#import "sokol_gfx" (Color);

Imm_Blend_Mode :: enum s32 {
    None     :: 0; /* No blending.
                        dstRGBA = srcRGBA */
    Blend    :: 1; /* Alpha blending.
                        dstRGB = (srcRGB * srcA) + (dstRGB * (1-srcA))
                        dstA = srcA + (dstA * (1-srcA)) */
    Add      :: 2; /* Color add.
                        dstRGB = (srcRGB * srcA) + dstRGB
                        dstA = dstA */
    Modulate :: 3; /* Color modulate.
                        dstRGB = srcRGB * dstRGB
                        dstA = dstA */
    Multiply :: 4; /* Color multiply.
                        dstRGB = (srcRGB * dstRGB) + (dstRGB * (1-srcA))
                        dstA = (srcA * dstA) + (dstA * (1-srcA)) */
    Count :: 5;
}

Imm_Circle :: Circle;

Text_Align :: struct {
    TL :: Top_Left;
    TC :: Top_Center;
    TR :: Top_Right;
    L  :: Left;
    C  :: Center;
    R  :: Right;
    BL :: Bottom_Left;
    BC :: Bottom_Center;
    BR :: Bottom_Right;

    Top_Left      :: Vector2.{0.0, 0.0};
    Top_Center    :: Vector2.{0.5, 0.0};
    Top_Right     :: Vector2.{1.0, 0.0};
    Left          :: Vector2.{0.0, 0.5};
    Center        :: Vector2.{0.5, 0.5};
    Right         :: Vector2.{1.0, 0.5};
    Bottom_Left   :: Vector2.{0.0, 0.5};
    Bottom_Center :: Vector2.{0.5, 0.5};
    Bottom_Right  :: Vector2.{1.0, 0.5};
}

test_log :: (tag: *u8, slog_level: u32, log_item_id: u32, message: *u8, line_nr: u32, filename: *u8, user_data: *void) -> void #c_call {
    new_context: Context;
    push_context new_context {
        log_level: Log_Level = ---;
        if slog_level == {
        case 0;  log_level = .Panic;
        case 1;  log_level = .Error;
        case 2;  log_level = .Warn;
        case;    log_level = .Info;
        }
        if tag       print("[%]", to_string(tag));
        print("[%]", log_level);
        print("[%]", log_item_id);
        if filename  print("%(%): ", path_filename(to_string(filename)), line_nr);
        if message   print("%\n",  to_string(message));
    }
}

render_init :: () {
    render_desc: sg_desc;
    render_desc._context.color_format = SG_Color_Format;
    render_desc._context.depth_format = .DEPTH_STENCIL;
    render_desc._context.sample_count = 4; // @Todo: MSAA
    render_desc.logger.func = test_log;
    sg_setup(*render_desc);
    if !sg_isvalid() {
        // @Todo: error handling
        warn(.Render, "Failed to initialize sokol_gfx.");
        return;
    }

    render_allocator: Allocator;
    render_allocator.proc = pool_allocator_proc;
    render_allocator.data = *render_pool;
    set_allocators(*render_pool);
    push_allocator(render_allocator);

    using render_ctx;
    max_vertices: u32 = Default_Max_Vertices;
    max_commands: u32 = Default_Max_Commands;

    vertices = NewArray(max_vertices, Imm_Vertex);
    uniforms = NewArray(max_commands, Imm_Uniform);
    commands = NewArray(max_commands, Imm_Command);
    if !vertices.data || !uniforms.data || !commands.data {
        warn(.Render, "Failed to initialize data buffers.");
        return;
    }

    vertex_buffer_desc: sg_buffer_desc;
    vertex_buffer_desc.size  = xx,no_check (vertices.count * size_of(Imm_Vertex));
    vertex_buffer_desc.type  = .VERTEXBUFFER;
    vertex_buffer_desc.usage = .STREAM;
    vertex_buffer = sg_make_buffer(*vertex_buffer_desc);
    if sg_query_buffer_state(vertex_buffer) != .VALID {
        warn(.Render, "Failed to initialize vertex buffer.");
        return;
    }

    {
        pixels: [4] u32 = ---;
        pixels[0] = 0xFFFFFFFF;
        pixels[1] = 0xFFFFFFFF;
        pixels[2] = 0xFFFFFFFF;
        pixels[3] = 0xFFFFFFFF;
        default_image_desc: sg_image_desc;
        using default_image_desc;
        type   = ._2D;
        width  = 2;
        height = 2;
        pixel_format = .RGBA8;
        min_filter   = .NEAREST;
        mag_filter   = .NEAREST;
        data.subimage[0][0] = sg_range.{pixels.data, size_of(type_of(pixels))};
        label = "Default_Image";

        default_image = sg_make_image(*default_image_desc);
        if sg_query_image_state(default_image) != .VALID {
            warn(.Render, "Failed to initialize Missing_Image.");
        }
    }

    base_shader := make_default_shader(Default_Frag_Shader);
    if sg_query_shader_state(base_shader) != .VALID {
        warn(.Render, "Failed to initialize base shader.");
        return;
    }

    circle_shader := make_circle_shader();
    if sg_query_shader_state(circle_shader) != .VALID {
        warn(.Render, "Failed to initialize circle shader.");
        return;
    }

    text_shader := make_text_shader();
    if sg_query_shader_state(text_shader) != .VALID {
        warn(.Render, "Failed to initialize text shader.");
        return;
    }

    pipes_ok := true;
    pipes_ok = pipes_ok && init_pipeline(.TRIANGLES,       .None, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.TRIANGLES,      .Blend, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.POINTS,          .None, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.POINTS,         .Blend, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.LINES,           .None, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.LINES,          .Blend, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.TRIANGLE_STRIP,  .None, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.TRIANGLE_STRIP, .Blend, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.LINE_STRIP,      .None, base_shader);
    pipes_ok = pipes_ok && init_pipeline(.LINE_STRIP,     .Blend, base_shader);
    if !pipes_ok {
        warn(.Render, "Failed to initialize default pipelines.");
        return;
    }
    circle_pipeline = make_pipeline(.TRIANGLES, .Blend, circle_shader);
    if circle_pipeline == SG_INVALID_ID {
        warn(.Render, "Failed to initialize circle pipeline.");
        return;
    }
    text_pipeline = make_pipeline(.TRIANGLES, .Blend, text_shader);
    if text_pipeline == SG_INVALID_ID {
        warn(.Render, "Failed to initialize text pipeline.");
        return;
    }

    init_value = Render_Init_Value;
}

render_deinit :: () {
    sg_shutdown();
    reset(*render_pool);
    render_ctx = Render_Context.{};
}

render_begin :: () {
    gpu_begin_frame();
    _profiler_draw_task = gpu_begin_task("Draw", Colors8.Medium_Purple);
    sg_begin_default_pass(*default_pass_action, window.size_i.x, window.size_i.y);
}

render_end :: () {
    sg_end_pass();
    sg_commit();
    gpu_end_task(_profiler_draw_task);
}

imm_begin :: () {
    using render_ctx;
    state_stack[cur_state] = state;
    cur_state += 1;

    inline imm_reset_state();
    state.base_vertex = cur_vertex;
    state.base_uniform = cur_uniform;
    state.base_command = cur_command;
}

imm_end :: () {
    using render_ctx;
    state = state_stack[cur_state];
    cur_state -= 1;
}

imm_flush :: () {
    using render_ctx;
    assert(cur_state > 0, "Invalid state! Did you forget an `imm_begin/imm_end`?");

    end_vertex  := cur_vertex;
    end_command := cur_command;

    cur_vertex  = state.base_vertex;
    cur_uniform = state.base_uniform;
    cur_command = state.base_command;

    if end_command <= cur_command  return;

    base_vertex := state.base_vertex;
    vertices_size: u32 = (end_vertex - base_vertex) * size_of(Imm_Vertex);
    vertex_range := sg_range.{*vertices[base_vertex], vertices_size};
    offset := sg_append_buffer(vertex_buffer, *vertex_range);
    if sg_query_buffer_overflow(vertex_buffer) {
        warn(.Render, "Vertex Overflow!");
        return;
    }

    Impossible_Id :: 0xFFFF_FFFF;

    cur_pipe: sg_pipeline    = Impossible_Id;
    cur_uniform_index: u32   = Impossible_Id;
    cur_images: [4] sg_image = .[Impossible_Id, Impossible_Id, Impossible_Id, Impossible_Id];

    bind: sg_bindings;
    bind.vertex_buffers[0]        = vertex_buffer;
    bind.vertex_buffer_offsets[0] = offset;

    for command_index: state.base_command..end_command-1 {
        command := *commands[command_index];

        if #complete command.type == {
        case .Viewport;
            sg_apply_viewport(
                command.viewport.x,
                command.viewport.y,
                command.viewport.width,
                command.viewport.height,
                true,
            );

        case .Scissor;
            sg_apply_scissor_rect(
                command.scissor.x,
                command.scissor.y,
                command.scissor.width,
                command.scissor.height,
                true,
            );

        case .Draw;
            using command;
            if draw.num_vertices == 0  continue command_index;
            apply_bindings := false;
            if draw.pipe != cur_pipe {
                cur_uniform_index = Impossible_Id;
                apply_bindings = true;
                cur_pipe = draw.pipe;
                sg_apply_pipeline(draw.pipe);
            }

            for image_index: 0..Max_Texture_Slots-1 {
                bind_image: sg_image = ---;
                if image_index < draw.images.count {
                    bind_image = draw.images.data[image_index];
                } else {
                    bind_image = SG_INVALID_ID;
                }
                if cur_images[image_index] != bind_image {
                    cur_images[image_index] = bind_image;
                    bind.fs_images[image_index] = bind_image;
                    apply_bindings = true;
                }
            }

            if apply_bindings  sg_apply_bindings(*bind);

            if cur_uniform_index != draw.uniform_index {
                cur_uniform_index = draw.uniform_index;
                uniform := *uniforms[cur_uniform_index];
                if uniform.size > 0 {
                    uniform_range := sg_range.{uniform.data.data, uniform.size};
                    vs_uniform_count, fs_uniform_count: s32 = ---;
                    sg_query_pipeline_uniforms(draw.pipe, *vs_uniform_count, *fs_uniform_count);
                    if vs_uniform_count > 0  sg_apply_uniforms(.VS, 0, *uniform_range);
                    if fs_uniform_count > 0  sg_apply_uniforms(.FS, 0, *uniform_range);
                }
            }

            sg_draw(xx,no_check (draw.vertex_index - base_vertex), xx,no_check draw.num_vertices, 1);

        case .None;
        }
    }
}

// -State

imm_set_pipeline :: (pipeline: sg_pipeline) {
    using render_ctx;
    state.pipeline = pipeline;

    if pipeline != SG_INVALID_ID {
        state.uniform = .{};
        return;
    }
    state.uniform.size = size_of(Color);
    state.uniform.data[0] = state.color.r;
    state.uniform.data[1] = state.color.g;
    state.uniform.data[2] = state.color.b;
    state.uniform.data[3] = state.color.a;
}

imm_reset_pipeline :: () #expand {
    imm_set_pipeline(SG_INVALID_ID);
}

imm_set_uniform :: (data: *void, size: u64) {
    using render_ctx;
    assert(size <= size_of(float) * Uniform_Size * 4);
    assert(size > 0);
    assert(data != null);
    memcpy(state.uniform.data.data, data, size);
    if size < state.uniform.size {
        memset(state.uniform.data.data + size, 0, xx,no_check (state.uniform.size - size));
    }
    state.uniform.size = size;
}

imm_reset_uniform :: () {
    using render_ctx;
    if state.uniform.size > 0 {
        memset(state.uniform.data.data, 0, xx,no_check state.uniform.size);
    }
    state.uniform.size = 0;
}

imm_set_image :: (channel: s32, image: sg_image) {
    using render_ctx;
    assert(cur_state > 0, "Invalid state! Did you forget an `imm_begin/imm_end`?");
    assert(channel >= 0 && channel < Max_Texture_Slots, "Invalid image channel `%`, expected `0-%`.", channel, Max_Texture_Slots);

    if state.images.data[channel] == image  return;

    state.images.data[channel] = image;

    images_count: s32 = xx,no_check state.images.count;
    for < max(channel, images_count-1)..0 {
        if state.images.data[channel] != SG_INVALID_ID {
            images_count = xx,no_check (it + 1);
        }
    }

    state.images.count = xx,no_check images_count;
}

imm_unset_image :: (channel: s32) #expand {
    imm_set_image(channel, SG_INVALID_ID);
}

imm_reset_image :: inline (channel: s32) {
    if channel == 0 {
        imm_set_image(channel, render_ctx.default_image);
    } else {
        imm_set_image(channel, SG_INVALID_ID);
    }
}

imm_set_default_image :: (channel: s32) #expand {
    imm_set_image(channel, render_ctx.default_image);
}

imm_set_blend_mode :: (blend_mode: Imm_Blend_Mode) #expand {
    render_ctx.state.blend_mode = blend_mode;
}

imm_reset_blend_mode :: () #expand {
    imm_set_blend_mode(.None);
}

imm_set_color :: (color: Color) {
    using render_ctx;
    state.color = color;

    if state.pipeline != SG_INVALID_ID  return;
    state.uniform.size = size_of(Color);
    state.uniform.data[0] = state.color.r;
    state.uniform.data[1] = state.color.g;
    state.uniform.data[2] = state.color.b;
    state.uniform.data[3] = state.color.a;
}

imm_reset_color :: () #expand {
    imm_set_color(Colors.White);
}

imm_viewport :: (x: s32, y: s32, width: s32, height: s32) {
    using render_ctx;
    if state.viewport.x == x
    && state.viewport.y == y
    && state.viewport.width  == width
    && state.viewport.height == height {
        return;
    }

    command := prev_command(1);
    if !command || command.type != .Viewport {
        command == next_command();
    }

    viewport := Recti.{x, y, width, height};
    << command = .{};
    command.type = .Viewport;
    command.viewport = viewport;

    if state.scissor.width >= 0 || state.scissor.height >= 0 {
        state.scissor.x += x - state.viewport.x;
        state.scissor.y += y - state.viewport.y;
    }

    state.viewport = viewport;
    state.thickness = max(1.0 / cast(float) width, 1.0 / cast(float) height);
    imm_reset_project();
}

imm_reset_viewport :: () #expand {
    imm_viewport(0, 0, state.frame_size.x, state.frame_size.y);
}

imm_scissor :: (x: s32, y: s32, width: s32, height: s32) {
    using render_ctx;
    if state.scissor.x == x
    && state.scissor.y == y
    && state.scissor.width  == width
    && state.scissor.height == height {
        return;
    }

    command := prev_command(1);
    if !command || command.type != .Scissor {
        command = next_command();
    }

    viewport_scissor := Recti.{state.viewport.x + x, state.viewport.y + y, width, height};

    if width < 0 && height < 0 {
        viewport_scissor.x = 0;
        viewport_scissor.y = 0;
        viewport_scissor.width  = state.frame_size.x;
        viewport_scissor.height = state.frame_size.y;
    }

    // << command = .{};
    command.type = .Scissor;
    command.scissor = viewport_scissor;

    state.scissor = .{x, y, width, height};
}

imm_reset_scissor :: () #expand {
    imm_scissor(0, 0, -1, -1);
}

imm_reset_state :: () {
    using render_ctx;
    state.frame_size = window.size_i;
    state.viewport.position = .{0, 0};
    state.viewport.size = window.size_i;
    state.scissor.position = .{0, 0};
    state.scissor.size = .{-1, -1};
    state.projection = make_projection(window.size.x, window.size.y);
    state.transform  = Transform_Identity;
    state.mvp        = state.projection;
    state.thickness  = max(1.0 / cast(float) window.size.x, 1.0 / cast(float) window.size.y);
    state.color      = Colors.White;
    state.uniform.size = size_of(Color);
    state.uniform.data[0] = Colors.White.r;
    state.uniform.data[1] = Colors.White.g;
    state.uniform.data[2] = Colors.White.b;
    state.uniform.data[3] = Colors.White.a;
    state.blend_mode = .Blend;
    state.pipeline = SG_INVALID_ID;
    state.images.count = 1;
    state.images.data[0] = default_image;
}

// -Transforms

imm_push_transform :: inline () {
    using render_ctx;
    assert(cur_transform < Max_Stack_Depth);
    transform_stack[cur_transform] = state.transform;
    cur_transform += 1;
}

imm_push_transform :: inline (transform: Transform) {
    using render_ctx;
    assert(cur_transform < Max_Stack_Depth);
    transform_stack[cur_transform] = state.transform;
    cur_transform  += 1;
    state.transform = transform;
    state.mvp       = state.projection * state.transform;
}

imm_pop_transform :: inline () {
    using render_ctx;
    assert(cur_transform > 0);
    cur_transform  -= 1;
    state.transform = transform_stack[cur_transform];
    state.mvp       = state.projection * state.transform;
}

imm_reset_transform :: inline () {
    state.transform = Transform_Identity;
    state.mvp       = state.projection * state.transform;
}

imm_project :: (left: float, right: float, top: float, bottom: float) {
    width  := right - left;
    height := top - bottom;
    transform := Transform.{
        2.0 / width, 0.0,
        0.0, 2.0 / height,
        -(right + left) / width,
        -(top + bottom) / height,
    };
    using render_ctx;
    state.projection = transform;
    state.mvp        = state.projection * state.transform;
}

imm_reset_project :: inline () {
    using render_ctx;
    state.projection = make_projection(state.viewport.width, state.viewport.height);
    state.mvp        = state.projection * state.transform;
}

imm_translate :: inline (offset: Vector2) {
    using render_ctx;
    translate_by(*state.transform, offset);
    state.mvp = state.projection * state.transform;
}

imm_rotate :: inline (theta: float) {
    using render_ctx;
    rotate_by(*state.transform, theta);
    state.mvp = state.projection * state.transform;
}

imm_rotate_at :: inline (theta: float, offset: Vector2) {
    using render_ctx;
    translate_by(*state.transform, offset);
    rotate_by(*state.transform, theta);
    translate_by(*state.transform, -offset);
    state.mvp = state.projection * state.transform;
}

imm_scale :: inline (scale: Vector2) {
    using render_ctx;
    scale_by(*state.transform, scale);
    state.mvp = state.projection * state.transform;
}

imm_scale_at :: inline (scale: Vector2, offset: Vector2) {
    using render_ctx;
    translate_by(*state.transform, offset);
    scale_by(*state.transform, scale);
    translate_by(*state.transform, -offset);
    state.mvp = state.projection * state.transform;
}

imm_scale :: inline (scale: float) {
    using render_ctx;
    scale_by(*state.transform, scale);
    state.mvp = state.projection * state.transform;
}

imm_scale_at :: inline (scale: float, offset: Vector2) {
    using render_ctx;
    translate_by(*state.transform, offset);
    scale_by(*state.transform, scale);
    translate_by(*state.transform, -offset);
    state.mvp = state.projection * state.transform;
}

// -Drawing

imm_points :: (points: [] Vector2) {
    using render_ctx;
    assert(points.count != 0);
    pipe := lookup_pipeline(.POINTS, state.blend_mode);
    render_solid_pipeline(pipe, points, state.thickness);
}

imm_point :: (point: Vector2) #expand {
    points: [] Vector2;
    points.count = 1;
    points.data  = *point;
    imm_points(points);
}

imm_lines :: (lines: [] Vector2) {
    using render_ctx;
    assert(lines.count != 0);
    pipe := lookup_pipeline(.LINES, state.blend_mode);
    render_solid_pipeline(pipe, lines, state.thickness);
}

imm_line :: (a: Vector2, b: Vector2) #expand {
    lines: [2] Vector2;
    lines[0] = a;
    lines[1] = b;
    imm_lines(lines);
}

imm_line_strip :: (points: [] Vector2) {
    using render_ctx;
    assert(points.count != 0);
    pipe := lookup_pipeline(.LINE_STRIP, state.blend_mode);
    render_solid_pipeline(pipe, points, state.thickness);
}

imm_filled_triangles :: (triangles: [] Vector2) {
    using render_ctx;
    assert(triangles.count != 0);
    pipe := lookup_pipeline(.TRIANGLES, state.blend_mode);
    render_solid_pipeline(pipe, triangles, state.thickness);
}

imm_filled_triangle :: (a: Vector2, b: Vector2, c: Vector2) #expand {
    triangles: [3] Vector2;
    triangles[0] = a;
    triangles[1] = b;
    triangles[2] = c;
    imm_filled_triangles(triangles);
}

imm_triangle_strip :: (points: [] Vector2) {
    using render_ctx;
    assert(points.count != 0);
    pipe := lookup_pipeline(.TRIANGLE_STRIP, state.blend_mode);
    render_solid_pipeline(pipe, points, state.thickness);
}

imm_filled_rects :: (rects: [] Rect) #expand {
    imm_set_default_image(0);
    imm_texture_rects(rects);
}

imm_filled_rect :: (rect: Rect) #expand {
    imm_set_default_image(0);
    rects: [] Rect;
    rects.count = 1;
    rects.data  = *rect;
    imm_texture_rects(rects);
}

imm_circles :: (circles: [] Imm_Circle, inner_radius := 0.0, outer_radius := 1.0) {
    using render_ctx;
    assert(circles.count != 0);

    // @Incomplete: This isn't using index buffers at the moment.
    num_vertices  := cast,no_check(u32) circles.count * 6;
    vertex_index  := cur_vertex;
    base_vertices := advance_vertices(num_vertices);
    assert(base_vertices != null);

    mvp := state.mvp;
    region := Rect.{FLOAT32_MAX, FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX};

    for 0..circles.count-1 {
        quad: [4] Vector2 = ---;
        quad[0] = .{circles[it].x - circles[it].radius, circles[it].y + circles[it].radius}; // bottom left
        quad[1] = .{circles[it].x + circles[it].radius, circles[it].y + circles[it].radius}; // bottom right
        quad[2] = .{circles[it].x + circles[it].radius, circles[it].y - circles[it].radius}; // top right
        quad[3] = .{circles[it].x - circles[it].radius, circles[it].y - circles[it].radius}; // top left
        xform_many(mvp, quad);

        for quad_index: 0..quad.count-1 {
            region.x1 = min(region.x1, quad[quad_index].x);
            region.y1 = min(region.y1, quad[quad_index].y);
            region.x2 = max(region.x2, quad[quad_index].x);
            region.y2 = max(region.y2, quad[quad_index].y);
        }

        Quad_UVs :: Vector2.[
            .{0.0, 1.0},
            .{1.0, 1.0},
            .{1.0, 0.0},
            .{0.0, 0.0},
        ];

        base_vertices[0].position = quad[0]; base_vertices[0].uv = Quad_UVs[0];
        base_vertices[1].position = quad[1]; base_vertices[1].uv = Quad_UVs[1];
        base_vertices[2].position = quad[2]; base_vertices[2].uv = Quad_UVs[2];
        base_vertices[3].position = quad[3]; base_vertices[3].uv = Quad_UVs[3];
        base_vertices[4].position = quad[0]; base_vertices[4].uv = Quad_UVs[0];
        base_vertices[5].position = quad[2]; base_vertices[5].uv = Quad_UVs[2];
        base_vertices += 6;
    }

    state.uniform.size = size_of(Color) + size_of(Vector2);
    state.uniform.data[0] = state.color.r;
    state.uniform.data[1] = state.color.g;
    state.uniform.data[2] = state.color.b;
    state.uniform.data[3] = state.color.a;
    state.uniform.data[4] = inner_radius;
    state.uniform.data[5] = outer_radius;
    render_queue_draw(circle_pipeline, region, vertex_index, num_vertices);
}

imm_circle :: (position: Vector2, radius: float, inner_radius := 0.0, outer_radius := 1.0) {
    circles: [1] Imm_Circle;
    circles[0].position = position;
    circles[0].radius   = radius;
    imm_circles(circles, inner_radius, outer_radius);
}

imm_texture_rects :: (rects: [] Rect) {
    using render_ctx;
    assert(rects.count != 0);

    // @Incomplete: This isn't using index buffers at the moment.
    num_vertices  := cast,no_check(u32) rects.count * 6;
    vertex_index  := cur_vertex;
    base_vertices := advance_vertices(num_vertices);
    assert(base_vertices != null);

    mvp := state.mvp;
    region := Rect.{FLOAT32_MAX, FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX};

    for 0..rects.count-1 {
        quad: [4] Vector2 = ---;
        quad[0] = .{rects[it].x,                   rects[it].y + rects[it].height}; // bottom left
        quad[1] = .{rects[it].x + rects[it].width, rects[it].y + rects[it].height}; // bottom right
        quad[2] = .{rects[it].x + rects[it].width, rects[it].y};                    // top right
        quad[3] = .{rects[it].x,                   rects[it].y};                    // top left
        xform_many(mvp, quad);

        for quad_index: 0..quad.count-1 {
            region.x1 = min(region.x1, quad[quad_index].x);
            region.y1 = min(region.y1, quad[quad_index].y);
            region.x2 = max(region.x2, quad[quad_index].x);
            region.y2 = max(region.y2, quad[quad_index].y);
        }

        Quad_UVs :: Vector2.[
            .{0.0, 1.0},
            .{1.0, 1.0},
            .{1.0, 0.0},
            .{0.0, 0.0},
        ];

        base_vertices[0].position = quad[0]; base_vertices[0].uv = Quad_UVs[0];
        base_vertices[1].position = quad[1]; base_vertices[1].uv = Quad_UVs[1];
        base_vertices[2].position = quad[2]; base_vertices[2].uv = Quad_UVs[2];
        base_vertices[3].position = quad[3]; base_vertices[3].uv = Quad_UVs[3];
        base_vertices[4].position = quad[0]; base_vertices[4].uv = Quad_UVs[0];
        base_vertices[5].position = quad[2]; base_vertices[5].uv = Quad_UVs[2];
        base_vertices += 6;
    }

    pipe := lookup_pipeline(.TRIANGLES, state.blend_mode);
    render_queue_draw(pipe, region, vertex_index, num_vertices);
}

imm_texture_rect :: (rect: Rect) #expand {
    rects: [] Rect;
    rects.count = 1;
    rects.data  = *rect;
    imm_texture_rects(rects);
}

imm_texture_quads :: (quads: [] Quad) {
    using render_ctx;
    assert(quads.count != 0);

    // @Incomplete: This isn't using index buffers at the moment.
    num_vertices  := cast,no_check(u32) quads.count * 6;
    vertex_index  := cur_vertex;
    base_vertices := advance_vertices(num_vertices);
    assert(base_vertices != null);

    mvp := state.mvp;
    region := Rect.{FLOAT32_MAX, FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX};

    for quad: quads {
        xform_many(mvp, quad.points);
        for point: quad.points {
            region.x1 = min(region.x1, point.x);
            region.y1 = min(region.y1, point.y);
            region.x2 = max(region.x2, point.x);
            region.y2 = max(region.y2, point.y);
        }

        Quad_UVs :: Vector2.[
            .{0.0, 0.0},
            .{1.0, 0.0},
            .{1.0, 1.0},
            .{0.0, 1.0},
        ];

        base_vertices[0].position = quad.points[0]; base_vertices[0].uv = Quad_UVs[0];
        base_vertices[1].position = quad.points[1]; base_vertices[1].uv = Quad_UVs[1];
        base_vertices[2].position = quad.points[2]; base_vertices[2].uv = Quad_UVs[2];
        base_vertices[3].position = quad.points[3]; base_vertices[3].uv = Quad_UVs[3];
        base_vertices[4].position = quad.points[0]; base_vertices[4].uv = Quad_UVs[0];
        base_vertices[5].position = quad.points[2]; base_vertices[5].uv = Quad_UVs[2];
        base_vertices += 6;
    }

    pipe := lookup_pipeline(.TRIANGLES, state.blend_mode);
    render_queue_draw(pipe, region, vertex_index, num_vertices);
}

imm_texture_quad :: (quad: Quad) #expand {
    quads: [] Quad;
    quads.count = 1;
    quads.data  = *quad;
    imm_texture_quads(quads);
}

imm_subrects :: (sources: [] Rect, dests: [] Rect) {
}

imm_subrect :: (source: Rect, dest: Rect) #expand {
    sources, dests: [] Rect;
    sources.count = 1;
    sources.data  = *source;
    dests.count   = 1;
    dests.data    = *dest;
    imm_subrects(source, dest);
}

imm_text :: (msdf: *MSDF_Font, text: string, position: Vector2, size: float, color := Colors.White, outline: float = 0.0) {
    using render_ctx;

    // @Incomplete: This isn't using index buffers at the moment.
    vertex_index  := cur_vertex;
    if cur_vertex + text.count * 12 > vertices.count {
        warn(.Render, "Vertices filled up!");
        return;
    }
    base_vertices := *vertices[cur_vertex];
    assert(base_vertices != null);

    mvp := state.mvp;
    region := Rect.{FLOAT32_MAX, FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX};
    num_vertices: u32;

    origin := position;
    last_codepoint: u32;

    imm_set_image(0, msdf.texture.id);
    head := text.data;
    while head < text.data + text.count {
        codepoint, continuation := one_utf32_codepoint(head);
        glyph, success := find_glyph(msdf, codepoint);
        if success {
            origin.x += get_kerning(msdf, codepoint, last_codepoint) * size;
    
            source := glyph.atlas;
            dest   := glyph.plane * size + origin;
    
            quad: [4] Vector2 = ---;
            quad[0] = .{dest.x,              dest.y + dest.height}; // bottom left
            quad[1] = .{dest.x + dest.width, dest.y + dest.height}; // bottom right
            quad[2] = .{dest.x + dest.width, dest.y};               // top right
            quad[3] = .{dest.x,              dest.y};               // top left
            quad_uvs: [4] Vector2 = ---;
            quad_uvs[0] = .{source.tl.x, source.br.y}; // bottom left
            quad_uvs[1] =   source.br;                 // bottom right
            quad_uvs[2] = .{source.br.x, source.tl.y}; // top right
            quad_uvs[3] =   source.tl;                 // top left
    
            xform_many(mvp, quad);
            for point: quad {
                region.x1 = min(region.x1, point.x);
                region.y1 = min(region.y1, point.y);
                region.x2 = max(region.x2, point.x);
                region.y2 = max(region.y2, point.y);
            }
    
            base_vertices[0].position = quad[0]; base_vertices[0].uv = quad_uvs[0];
            base_vertices[1].position = quad[1]; base_vertices[1].uv = quad_uvs[1];
            base_vertices[2].position = quad[2]; base_vertices[2].uv = quad_uvs[2];
            base_vertices[3].position = quad[3]; base_vertices[3].uv = quad_uvs[3];
            base_vertices[4].position = quad[0]; base_vertices[4].uv = quad_uvs[0];
            base_vertices[5].position = quad[2]; base_vertices[5].uv = quad_uvs[2];
            base_vertices += 6;
            num_vertices  += 6;
    
            origin.x += glyph.advance_x * size;
            last_codepoint = codepoint;
        }
        head += continuation;
    }

    cur_vertex += num_vertices;
    state.uniform.size = size_of(Color) + size_of(Vector2);
    state.uniform.data[0] = color.r;
    state.uniform.data[1] = color.g;
    state.uniform.data[2] = color.b;
    state.uniform.data[3] = color.a;
    state.uniform.data[4] = msdf.pixel_range;
    state.uniform.data[5] = outline;
    render_queue_draw(text_pipeline, region, vertex_index, num_vertices);
}

imm_text_aligned :: inline (msdf: *MSDF_Font, text: string, position: Vector2, size: float, origin := Text_Align.C, color := Colors.White) -> Vector2 #expand {
    text_size := measure_text(msdf, text, size);
    offset    := text_size * origin;
    imm_text(msdf, text, position - offset, size, color);
    return text_size;
}

imm_text_outlined :: (msdf: *MSDF_Font, text: string, position: Vector2, size: float, outline := 2.0, fill := Colors.White, stroke := Colors.Black) #expand {
    // @Speed: Fix this so it doesn't calculate each glyph twice.
    imm_text(msdf, text, position, size, stroke, outline);
    imm_text(msdf, text, position, size, fill);
}

imm_text_outlined_aligned :: inline (msdf: *MSDF_Font, text: string, position: Vector2, size: float, origin := Text_Align.C, outline := 2.0, fill := Colors.White, stroke := Colors.Black) -> Vector2 #expand {
    text_size := measure_text(msdf, text, size);
    offset    := text_size * origin;
    imm_text_outlined(msdf, text, position - offset, size, outline, fill, stroke);
    return text_size;
}

// -Utility

make_projection :: inline (width: s32, height: s32) -> Transform {
    return make_projection(cast(float) width, cast(float) height);
}

make_projection :: inline (width: float, height: float) -> Transform {
    return .{
        2.0 / width, 0.0,
        0.0, -2.0 / height,
        -1.0, 1.0,
    };
}

#scope_module

render_ctx: Render_Context;
default_pass_action := sg_pass_action.{
    colors = .[.{.CLEAR, .{0.0, 0.1, 0.2, 1.0}}, .{}, .{}, .{}],
};

// @Incomplete: Add Metal and D3D11.
//  #if METAL or D3D11: .BGRA8;
SG_Color_Format :: sg_pixel_format.RGBA8;

#scope_file

Render_Init_Value    :: 0x18008135;
Default_Max_Vertices :: 65536;
Default_Max_Commands :: 16384;
Max_Stack_Depth      :: 64;
Max_Texture_Slots    :: 4;

render_pool: Pool;
_profiler_draw_task: int;

Imm_Images_Uniform :: struct {
    count: u32;
    _image_1: sg_image;
    _image_2: sg_image;
    _image_3: sg_image;
    _image_4: sg_image;
#place _image_1;
    data: [4] sg_image;
}

Imm_Draw_Parameters :: struct {
    pipe: sg_pipeline;
    images: Imm_Images_Uniform;
    region: Rect;
    uniform_index: u32;
    vertex_index:  u32;
    num_vertices:  u32;
}

Imm_Vertex :: struct {
    position: Vector2;
    uv:       Vector2;
}

Imm_Uniform :: struct {
    size: u64;
    data: [Uniform_Size * 4] float;
#place data;
    floats: [Uniform_Size * 4] float;
#place data;
    ints: [Uniform_Size * 4] s32;
}

Command_Type :: enum s32 {
    None :: 0;
    Draw;
    Viewport;
    Scissor;
}

Imm_Command :: struct {
    type: Command_Type;
    using parameters: union {
        draw: Imm_Draw_Parameters;
        viewport: Recti;
        scissor:  Recti;
    }
}

Render_State :: struct {
    frame_size: Point2;
    viewport: Recti;
    scissor:  Recti;

    projection: Transform;
    transform: Transform = Transform_Identity;
    mvp: Transform;

    thickness: float;
    color: Color;
    images: Imm_Images_Uniform;
    uniform: Imm_Uniform;
    blend_mode: Imm_Blend_Mode;
    pipeline: sg_pipeline;

    base_vertex:  u32;
    base_uniform: u32;
    base_command: u32;
}

Render_Context :: struct {
    init_value: u32;

    vertex_buffer: sg_buffer;
    default_image: sg_image;
    pipelines: [cast(s64) sg_primitive_type.NUM * cast(s64) Imm_Blend_Mode.Count] sg_pipeline;
    circle_pipeline: sg_pipeline;
    text_pipeline: sg_pipeline;

    cur_vertex:  u32;
    cur_command: u32;
    cur_uniform: u32;
    vertices: [] Imm_Vertex;
    uniforms: [] Imm_Uniform;
    commands: [] Imm_Command;

    state: Render_State;

    cur_transform: u32;
    cur_state:     u32;
    transform_stack: [Max_Stack_Depth] Transform;
    state_stack:     [Max_Stack_Depth] Render_State;
}

make_default_shader :: (frag_shader: string) -> sg_shader {
    shader_desc: sg_shader_desc;
    shader_desc.attrs[0].name = "vPosUV";
    shader_desc.attrs[0].sem_name = "Position";
    shader_desc.attrs[0].sem_index = 0;

    shader_desc.vs.source = Default_Vert_Shader;

    shader_desc.fs.source = frag_shader.data;
    shader_desc.fs.uniform_blocks[0].size = size_of(Color);
    shader_desc.fs.uniform_blocks[0].uniforms[0].name = "color";
    shader_desc.fs.uniform_blocks[0].uniforms[0].type = .FLOAT4;

    shader_desc.fs.images[0].name = "TEXTURE";
    shader_desc.fs.images[0].image_type = ._2D;

    return sg_make_shader(*shader_desc);
}

make_circle_shader :: () -> sg_shader {
    shader_desc: sg_shader_desc;
    shader_desc.attrs[0].name = "vPosUV";
    shader_desc.attrs[0].sem_name = "Position";
    shader_desc.attrs[0].sem_index = 0;

    shader_desc.vs.source = Default_Vert_Shader;

    shader_desc.fs.source = Circle_Frag_Shader;
    shader_desc.fs.uniform_blocks[0].size = size_of(Color) + size_of(Vector2);
    shader_desc.fs.uniform_blocks[0].uniforms[0].name = "color";
    shader_desc.fs.uniform_blocks[0].uniforms[0].type = .FLOAT4;
    shader_desc.fs.uniform_blocks[0].uniforms[1].name = "radius";
    shader_desc.fs.uniform_blocks[0].uniforms[1].type = .FLOAT2;

    shader_desc.fs.images[0].name = "TEXTURE";
    shader_desc.fs.images[0].image_type = ._2D;

    return sg_make_shader(*shader_desc);
}

make_text_shader :: () -> sg_shader {
    shader_desc: sg_shader_desc;
    shader_desc.attrs[0].name = "vPosUV";
    shader_desc.attrs[0].sem_name = "Position";
    shader_desc.attrs[0].sem_index = 0;

    shader_desc.vs.source = Default_Vert_Shader;

    shader_desc.fs.source = Text_Frag_Shader;
    shader_desc.fs.uniform_blocks[0].size = size_of(Color) + size_of(Vector2);
    shader_desc.fs.uniform_blocks[0].uniforms[0].name = "color";
    shader_desc.fs.uniform_blocks[0].uniforms[0].type = .FLOAT4;
    shader_desc.fs.uniform_blocks[0].uniforms[1].name = "text_params";
    shader_desc.fs.uniform_blocks[0].uniforms[1].type = .FLOAT2;

    shader_desc.fs.images[0].name = "TEXTURE";
    shader_desc.fs.images[0].image_type = ._2D;

    return sg_make_shader(*shader_desc);
}

make_pipeline :: (target_primitive_type: sg_primitive_type, blend_mode: Imm_Blend_Mode, shader: sg_shader) -> sg_pipeline {
    blend := get_blend_state(blend_mode);

    primitive_type := target_primitive_type;
    if primitive_type == .DEFAULT  primitive_type = .TRIANGLES;

    pipe_desc: sg_pipeline_desc;
    pipe_desc.shader = shader;
    pipe_desc.layout.buffers[0].stride = size_of(Imm_Vertex);
    pipe_desc.layout.attrs[0].format = .FLOAT4;
    pipe_desc.colors[0].pixel_format = SG_Color_Format;
    pipe_desc.colors[0].blend = blend;
    pipe_desc.primitive_type = primitive_type;

    pipe := sg_make_pipeline(*pipe_desc);
    if pipe != SG_INVALID_ID && sg_query_pipeline_state(pipe) != .VALID {
        sg_destroy_pipeline(pipe);
        pipe = SG_INVALID_ID;
    }
    return pipe;
}

init_pipeline :: (primitive_type: sg_primitive_type, blend_mode: Imm_Blend_Mode, shader: sg_shader) -> bool {
    pipe := make_pipeline(primitive_type, blend_mode, shader);
    pipe_index := (cast(s64) primitive_type * cast(s64) Imm_Blend_Mode.Count) + cast(s64) blend_mode;
    if pipe == SG_INVALID_ID  return false;
    render_ctx.pipelines[pipe_index] = pipe;
    return true;
}

lookup_pipeline :: (primitive_type: sg_primitive_type, blend_mode: Imm_Blend_Mode) -> sg_pipeline #expand {
    pipe_index := (cast(s64) primitive_type * cast(s64) Imm_Blend_Mode.Count) + cast(s64) blend_mode;
    return render_ctx.pipelines[pipe_index];
}

get_blend_state :: (blend_mode: Imm_Blend_Mode) -> sg_blend_state {
    blend: sg_blend_state;
    if blend_mode == {
    case .None;
        blend.enabled = false;
        blend.src_factor_rgb = .ONE;
        blend.dst_factor_rgb = .ZERO;
        blend.op_rgb = .ADD;
        blend.src_factor_alpha = .ONE;
        blend.dst_factor_alpha = .ZERO;
        blend.op_alpha = .ADD;
    case .Blend;
        blend.enabled = true;
        blend.src_factor_rgb = .SRC_ALPHA;
        blend.dst_factor_rgb = .ONE_MINUS_SRC_ALPHA;
        blend.op_rgb = .ADD;
        blend.src_factor_alpha = .ONE;
        blend.dst_factor_alpha = .ONE_MINUS_SRC_ALPHA;
        blend.op_alpha = .ADD;
    case .Add;
        blend.enabled = true;
        blend.src_factor_rgb = .SRC_ALPHA;
        blend.dst_factor_rgb = .ONE;
        blend.op_rgb = .ADD;
        blend.src_factor_alpha = .ZERO;
        blend.dst_factor_alpha = .ONE;
        blend.op_alpha = .ADD;
    case .Modulate;
        blend.enabled = true;
        blend.src_factor_rgb = .DST_COLOR;
        blend.dst_factor_rgb = .ZERO;
        blend.op_rgb = .ADD;
        blend.src_factor_alpha = .ZERO;
        blend.dst_factor_alpha = .ONE;
        blend.op_alpha = .ADD;
    case .Multiply;
        blend.enabled = true;
        blend.src_factor_rgb = .DST_COLOR;
        blend.dst_factor_rgb = .ONE_MINUS_SRC_ALPHA;
        blend.op_rgb = .ADD;
        blend.src_factor_alpha = .DST_ALPHA;
        blend.dst_factor_alpha = .ONE_MINUS_SRC_ALPHA;
        blend.op_alpha = .ADD;
    case;
        blend.enabled = false;
        blend.src_factor_rgb = .ONE;
        blend.dst_factor_rgb = .ZERO;
        blend.op_rgb = .ADD;
        blend.src_factor_alpha = .ONE;
        blend.dst_factor_alpha = .ZERO;
        blend.op_alpha = .ADD;
    }
    return blend;
}

advance_vertices :: inline (count: u32) -> *Imm_Vertex {
    using render_ctx;
    if cur_vertex + count > vertices.count {
        warn(.Render, "Vertices filled up!");
        return null;
    }

    new_vertices := *vertices[cur_vertex];
    cur_vertex += count;
    return new_vertices;
}

prev_uniform :: () -> *Imm_Uniform #must #expand {
    using render_ctx;
    if cur_uniform <= 0  return null;
    return *uniforms[cur_uniform - 1];
}

prev_command :: (count: u32) -> *Imm_Command #must #expand {
    using render_ctx;
    if (cur_command - state.base_command) < count  return null;
    return *commands[cur_command - count];
}

next_command :: () -> *Imm_Command #must #expand {
    using render_ctx;
    if cur_command >= commands.count {
        warn(.Render, "Commands filled up!");
        return null;
    }

    new_command := *commands[cur_command];
    cur_command += 1;
    return new_command;
}

Invalid_Vertex :: 0xFFFFFFFF;

render_queue_draw :: (pipe: sg_pipeline, region: Rect, vertex_index: u32, num_vertices: u32) -> u32 {
    using render_ctx;
    if state.pipeline != SG_INVALID_ID  pipe = state.pipeline;

    if pipe == SG_INVALID_ID {
        cur_vertex -= num_vertices;
        return Invalid_Vertex;
    }

    if region.x1 > 1.0 || region.y1 > 1.0 || region.x2 < -1.0 || region.y2 < -1.0 {
        cur_vertex -= num_vertices;
        return Invalid_Vertex;
    }

    #if Batch_Optimizer_Depth > 0 {
        batch_result := merge_batch_command(pipe, state.images, state.uniform, region, vertex_index, num_vertices);
        if batch_result != Invalid_Vertex  return batch_result;
    }

    previous_uniform := prev_uniform();
    reuse_uniform := previous_uniform && (memcmp(previous_uniform, *state.uniform, size_of(Imm_Uniform)) == 0);
    if !reuse_uniform {
        if cur_uniform >= uniforms.count {
            warn(.Render, "Uniforms filled up!");
            cur_vertex -= num_vertices;
            return Invalid_Vertex;
        }
        uniforms[cur_uniform] = state.uniform;
        cur_uniform += 1;
    }
    uniform_index := cur_uniform - 1;

    command := next_command();
    if !command {
        cur_vertex -= num_vertices;
        return Invalid_Vertex;
    }

    command.type = .Draw;
    command.draw.pipe = pipe;
    command.draw.images = state.images;
    command.draw.region = region;
    command.draw.uniform_index = uniform_index;
    command.draw.vertex_index  = vertex_index;
    command.draw.num_vertices  = num_vertices;
    return vertex_index;
}

merge_batch_command :: (pipe: sg_pipeline, images: Imm_Images_Uniform, uniform: Imm_Uniform, region: Rect, vertex_index: u32, num_vertices: u32) -> u32 {
    previous: *Imm_Command;
    intermediates: [Batch_Optimizer_Depth] *Imm_Command;
    intermediate_count: s64;

    lookup_depth: u32 = Batch_Optimizer_Depth;
    depth: u32;
    while depth < lookup_depth {
        defer depth += 1;

        command := prev_command(depth + 1);
        if !command  break;
        if command.type == .None {
            lookup_depth += 1;
            continue;
        }
        if command.type != .Draw  break;

        if command.draw.pipe == pipe
        && memcmp(*images,  *command.draw.images, size_of(Imm_Images_Uniform)) == 0
        && memcmp(*uniform, *render_ctx.uniforms[command.draw.uniform_index], size_of(Imm_Uniform)) == 0 {
            previous = command;
            break;
        } else {
            intermediates[intermediate_count] = command;
            intermediate_count += 1;
        }
    }

    if !previous  return Invalid_Vertex;

    overlaps_next, overlaps_prev: bool;
    prev_region := previous.draw.region;
    for 0..intermediate_count-1 {
        intermediate_region := intermediates[it].draw.region;
        if overlaps(region, intermediate_region) {
            overlaps_next = true;
            if overlaps_prev  return Invalid_Vertex;
        }
        if overlaps(prev_region, intermediate_region) {
            overlaps_prev = true;
            if overlaps_next  return Invalid_Vertex;
        }
    }

    if !overlaps_next { // Batch in the previous draw command.
        batch_index: u32 = ---;
        if intermediate_count > 0 {
            if render_ctx.cur_vertex + num_vertices > render_ctx.vertices.count  return Invalid_Vertex;
            batch_index = previous.draw.vertex_index + previous.draw.num_vertices;
            move_count := render_ctx.cur_vertex - batch_index;
            {
                // memmove in reverse
                to   := *render_ctx.vertices[batch_index + num_vertices];
                from := *render_ctx.vertices[batch_index];
                for < move_count-1..0 {
                    to[it] = from[it];
                }
            }
            memcpy(
                *render_ctx.vertices[batch_index],
                *render_ctx.vertices[vertex_index + num_vertices],
                num_vertices * size_of(Imm_Vertex)
            );

            // Shift all the vertices forward.
            for 0..intermediate_count-1 {
                intermediates[it].draw.vertex_index += num_vertices;
            }
        } else {
            batch_index = vertex_index;
        }

        prev_region.x1 = min(prev_region.x1, region.x1);
        prev_region.y1 = min(prev_region.y1, region.y1);
        prev_region.x2 = max(prev_region.x2, region.x2);
        prev_region.y2 = max(prev_region.y2, region.y2);
        previous.draw.num_vertices += num_vertices;
        previous.draw.region        = prev_region;
        return batch_index;
    }

    // Batch in the next draw command.
    command := next_command();
    prev_num_vertices := previous.draw.num_vertices;
    if render_ctx.cur_vertex + prev_num_vertices > render_ctx.vertices.count  return Invalid_Vertex;

    {
        // memmove in reverse
        to   := *render_ctx.vertices[vertex_index + prev_num_vertices];
        from := *render_ctx.vertices[vertex_index];
        for < num_vertices-1..0  to[it] = from[it];
    }
    memcpy(
        *render_ctx.vertices[vertex_index],
        *render_ctx.vertices[previous.draw.vertex_index],
        prev_num_vertices * size_of(Imm_Vertex)
    );

    prev_region.x1 = min(prev_region.x1, region.x1);
    prev_region.y1 = min(prev_region.y1, region.y1);
    prev_region.x2 = max(prev_region.x2, region.x2);
    prev_region.y2 = max(prev_region.y2, region.y2);
    render_ctx.cur_vertex += prev_num_vertices;
    num_vertices          += prev_num_vertices;

    command.type = .Draw;
    command.draw.pipe   = pipe;
    command.draw.images = images;
    command.draw.region = prev_region;
    command.draw.uniform_index = previous.draw.uniform_index;
    command.draw.vertex_index  = vertex_index;
    command.draw.num_vertices  = num_vertices;

    previous.type = .None;
    return vertex_index;
}

render_solid_pipeline :: (pipe: sg_pipeline, new_vertices: [] Vector2, thickness: float) {
    using render_ctx;
    vertex_index := cur_vertex;
    transformed_vertices := advance_vertices(xx,no_check new_vertices.count);
    mvp          := state.mvp;
    region := Rect.{FLOAT32_MAX, FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX};
    for 0..new_vertices.count-1 {
        new_position := xform(mvp, new_vertices[it]);
        region.x1 = min(region.x1, new_position.x - thickness);
        region.y1 = min(region.y1, new_position.y - thickness);
        region.x2 = max(region.x2, new_position.x + thickness);
        region.y2 = max(region.y2, new_position.y + thickness);
        transformed_vertices[it].position = new_position;
        transformed_vertices[it].uv = .{0, 0};
    }
    render_queue_draw(pipe, region, vertex_index, xx,no_check new_vertices.count);
}
