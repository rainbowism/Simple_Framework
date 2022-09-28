#if ENABLE_PROFILER {
    imgui_render_profiler :: () {
        title := tprint(
            "Profiler [%ms, %fps, % draw]###ProfilerWindow\0",
            formatFloat(window.time.fps_average * 1000, trailing_width = 3, zero_removal = .NO),
            ceil(1.0 / window.time.fps_average),
            render_ctx.draw_calls
        );

        MAX_GRAPH_HEIGHT :: 300;
        LEGEND_WIDTH     :: 200;
        MIN_WINDOW_SIZE  :: Vector2.{100 + LEGEND_WIDTH, 100};
        MAX_WINDOW_SIZE  :: Vector2.{32767, MAX_GRAPH_HEIGHT};

        size_constraints := ImGui.GetStyle().WindowPadding * 2 + MAX_WINDOW_SIZE;
        ImGui.SetNextWindowSizeConstraints(MIN_WINDOW_SIZE, size_constraints);
        ImGui.PushStyleColor(.WindowBg, 0x0F0F0F80);
        defer ImGui.PopStyleColor();
        defer ImGui.End();
        if !ImGui.Begin(title.data, null, .NoScrollbar) return;

        canvas_size  := ImGui.GetContentRegionAvail();
        size_margin  := ImGui.GetStyle().ItemSpacing.y;
        graph_width  := canvas_size.x - LEGEND_WIDTH;
        graph_height := min((canvas_size.y - size_margin) * 0.5, MAX_GRAPH_HEIGHT);

        render_timings(_cpu_profiler, graph_width, LEGEND_WIDTH, graph_height, 0, CPU_FRAME_TIME);
        render_timings(_gpu_profiler, graph_width, LEGEND_WIDTH, graph_height, 0, GPU_FRAME_TIME);
    }
} else {
    imgui_render_profiler :: () #expand {}
}

#scope_file

CPU_FRAME_TIME :: 120.0;
GPU_FRAME_TIME :: 60.0;
FRAME_WIDTH    :: 3.0;
FRAME_SPACING  :: 1.0;

render_timings :: (profiler: Profiler, graph_width: float, legend_width: float, height: float, frame_offset: int, $max_frame_time: float) {
    draw_list := ImGui.GetWindowDrawList();
    widget_pos := ImGui.GetCursorScreenPos();
    render_graph(draw_list, profiler, widget_pos, xy(graph_width, height), frame_offset, max_frame_time);
    render_legend(draw_list, profiler, widget_pos + xy(graph_width, 0), xy(legend_width, height), frame_offset, max_frame_time);
    ImGui.Dummy(xy(graph_width + legend_width, height));
}

render_graph :: (draw_list: *ImGui.ImDrawList, profiler: Profiler, position: Vector2, size: Vector2, frame_offset: int, $max_frame_time: float) {
    add_rect(draw_list, position, position + size, 0xFFFFFFFF);
    HEIGHT_THRESHOLD :: 1.0;

    for 0..MAX_PROFILER_FRAMES-1 {
        frame_index := (profiler.index - it - frame_offset - 1 + MAX_PROFILER_FRAMES * 2) % MAX_PROFILER_FRAMES;

        frame_position := position + xy(size.x - 1.0 - FRAME_WIDTH - (FRAME_WIDTH + FRAME_SPACING) * it, size.y - 1.0);

        if frame_position.x < position.x + 1  return;

        task_position := frame_position;
        cur_frame     := profiler.frames[frame_index];
        for cur_frame.tasks {
            start_height: float = xx (it.start * max_frame_time) * size.y;
            end_height:   float = xx (it.end   * max_frame_time) * size.y;
            if start_height > size.y || end_height > size.y  continue;
            if abs(end_height - start_height) < HEIGHT_THRESHOLD  continue;
            add_rect_filled(draw_list, task_position + xy(0.0, -start_height), task_position + xy(FRAME_WIDTH, -end_height), it.color);
        }
    }
}

render_legend :: (draw_list: *ImGui.ImDrawList, profiler: Profiler, position: Vector2, size: Vector2, frame_offset: int, $max_frame_time: float) {
    MARKER_LEFT_RECT_MARGIN   :: 3.0;
    MARKER_LEFT_RECT_WIDTH    :: 5.0;
    MARKER_MID_WIDTH          :: 30.0;
    MARKER_RIGHT_RECT_WIDTH   :: 10.0;
    MARKER_RIGHT_RECT_MARGIN  :: 3.0;
    MARKER_RIGHT_RECT_HEIGHT  :: 10.0;
    MARKER_RIGHT_RECT_SPACING :: 4.0;
    NAME_OFFSET               :: Vector2.{30.0, 0.0};
    TEXT_MARGIN               :: Vector2.{5.0, -3.0};

    frame_index := (profiler.index - frame_offset - 1 + MAX_PROFILER_FRAMES * 2) % MAX_PROFILER_FRAMES;
    cur_frame   := profiler.frames[frame_index];

    for cur_frame.tasks {
        start_height: float = xx (it.start * max_frame_time) * size.y;
        end_height:   float = xx (it.end   * max_frame_time) * size.y;

        if start_height > size.y || end_height > size.y  continue;

        marker_left_rect_min := position             + xy(MARKER_LEFT_RECT_MARGIN, size.y);
        marker_left_rect_max := marker_left_rect_min + xy(MARKER_LEFT_RECT_WIDTH,  0.0);
        marker_left_rect_min.y -= start_height;
        marker_left_rect_max.y -= end_height;

        marker_right_rect_min := position + xy(
            MARKER_LEFT_RECT_MARGIN + MARKER_LEFT_RECT_WIDTH + MARKER_MID_WIDTH,
            size.y - MARKER_RIGHT_RECT_MARGIN - (MARKER_RIGHT_RECT_HEIGHT + MARKER_RIGHT_RECT_SPACING) * it_index
        );
        marker_right_rect_max := marker_right_rect_min + xy(MARKER_RIGHT_RECT_WIDTH, -MARKER_RIGHT_RECT_HEIGHT);
        render_task_marker(draw_list, marker_left_rect_min, marker_left_rect_max, marker_right_rect_min, marker_right_rect_max, it.color);

        task_time := (it.end - it.start) * 1000;
        add_text(draw_list, marker_right_rect_max + TEXT_MARGIN, it.color, tprint("[%ms] %", formatFloat(task_time, trailing_width = 3, zero_removal = .NO), it.name));
    }
}


render_task_marker :: (draw_list: *ImGui.ImDrawList, left_min_point: Vector2, left_max_point: Vector2, right_min_point: Vector2, right_max_point: Vector2, color: u32) {
    add_rect_filled(draw_list, left_min_point,  left_max_point, color);
    add_rect_filled(draw_list, right_min_point, right_max_point, color);
    points: [4] Vector2;
    points[0] = xy(left_max_point.x,  left_min_point.y);
    points[1] = xy(left_max_point.x,  left_max_point.y);
    points[2] = xy(right_min_point.x, right_max_point.y);
    points[3] = xy(right_min_point.x, right_min_point.y);
    add_convex_poly_filled(draw_list, points.data, points.count, color);
}

add_text               :: ImGui.ImDrawList.AddText;
add_rect               :: ImGui.ImDrawList.AddRect;
add_rect_filled        :: ImGui.ImDrawList.AddRectFilled;
add_convex_poly_filled :: ImGui.ImDrawList.AddConvexPolyFilled;

ImGui :: #import "ImGui";
