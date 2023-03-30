SAT_Polygon :: struct (N: int) {
    points: [N] Vector2;
}

SAT_Rect :: struct {
    using #as polygon: SAT_Polygon(4);

#place polygon;
    tl: Vector2 = ---;
    tr: Vector2 = ---;
    br: Vector2 = ---;
    bl: Vector2 = ---;
}

Quad :: SAT_Rect;

project_axis_normalized :: (current_point: Vector2, next_point: Vector2) -> Vector2 {
    axis: Vector2 = ---;
    axis.x = -(next_point.y - current_point.y);
    axis.y =   next_point.x - current_point.x;
    magnitude := sqrt(axis.x * axis.x + axis.y * axis.y);
    axis.x = axis.x / magnitude;
    axis.y = axis.y / magnitude;
    return axis;
}

sat :: (shape_a: SAT_Polygon($A), shape_b: SAT_Polygon($B)) -> bool #must #no_abc {
    for 0..A-1 {
        projected := project_axis_normalized(shape_a.points[it], shape_a.points[(it + 1) % A]);

        min_r1 :=  FLOAT32_MAX;
        max_r1 := -FLOAT32_MAX;
        for 0..A-1 {
            q := shape_a.points[it].x * projected.x + shape_a.points[it].y * projected.y;
            min_r1 = min(min_r1, q);
            max_r1 = max(max_r1, q);
        }

        min_r2 :=  FLOAT32_MAX;
        max_r2 := -FLOAT32_MAX;
        for 0..B-1 {
            q := shape_b.points[it].x * projected.x + shape_b.points[it].y * projected.y;
            min_r2 = min(min_r2, q);
            max_r2 = max(max_r2, q);
        }

        if !(max_r2 >= min_r1 && max_r1 >= min_r2)  return false;
    }

    for 0..B-1 {
        projected := project_axis_normalized(shape_b.points[it], shape_b.points[(it + 1) % B]);

        min_r1 :=  FLOAT32_MAX;
        max_r1 := -FLOAT32_MAX;
        for 0..B-1 {
            q := shape_b.points[it].x * projected.x + shape_b.points[it].y * projected.y;
            min_r1 = min(min_r1, q);
            max_r1 = max(max_r1, q);
        }

        min_r2 :=  FLOAT32_MAX;
        max_r2 := -FLOAT32_MAX;
        for 0..A-1 {
            q := shape_a.points[it].x * projected.x + shape_a.points[it].y * projected.y;
            min_r2 = min(min_r2, q);
            max_r2 = max(max_r2, q);
        }

        if !(max_r2 >= min_r1 && max_r1 >= min_r2)  return false;
    }

    return true;
}

point_in_rect :: inline (point: Vector2, rect: SAT_Rect) -> bool {
    if cross(rect.points[1] - rect.points[0], point - rect.points[0]) < 0  return false;
    if cross(rect.points[2] - rect.points[1], point - rect.points[1]) < 0  return false;
    if cross(rect.points[3] - rect.points[2], point - rect.points[2]) < 0  return false;
    if cross(rect.points[0] - rect.points[3], point - rect.points[3]) < 0  return false;
    return true;
}
