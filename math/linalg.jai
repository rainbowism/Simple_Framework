circle_intersecting :: inline (a: Vector2, b: Vector2, radius: float) -> bool {
    return inline inside_radius(a - b, radius);
}

circle_not_intersecting :: inline (a: Vector2, b: Vector2, radius: float) -> bool {
    return inline outside_radius(a - b, radius);
}

inside_radius :: inline (v: Vector2, radius: float) -> bool {
    return v.x * v.x + v.y * v.y <= radius * radius;
}

outside_radius :: inline (v: Vector2, radius: float) -> bool {
    return v.x * v.x + v.y * v.y >= radius * radius;
}

point_in_rect :: (point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool {
    ab := b - a;
    am := point - a;
    bc := c - b;
    bm := point - b;
    dot_ab_am := dot(ab, am);
    dot_ab_ab := dot(ab, ab);
    dot_bc_bm := dot(bc, bm);
    dot_bc_bc := dot(bc, bc);
    return 0 <= dot_ab_am && dot_ab_am <= dot_ab_ab && 0 <= dot_bc_bm && dot_bc_bm <= dot_bc_bc;
}

Rect :: struct {
    x1, y1: float;
    x2, y2: float;

#place x1;
    x: float = ---;
    y: float = ---;
    w: float = ---;
    h: float = ---;
#place x2;
    width:  float = ---;
    height: float = ---;

#place x1;
    left:   float = ---;
    top:    float = ---;
    right:  float = ---;
    bottom: float = ---;

#place x1;
    position: Vector2 = ---;
    size:     Vector2 = ---;

#place x1;
    tl: Vector2 = ---;
    br: Vector2 = ---;

#place x1;
    floats: [4] float = ---;
}

operator * :: (a: Rect, b: float) -> Rect {
    r: Rect = ---;
    r.x = a.x * b;
    r.y = a.y * b;
    r.width  = a.width  * b;
    r.height = a.height * b;
    return r;
}

operator + :: (a: Rect, b: Vector2) -> Rect {
    r: Rect = ---;
    r.x = a.x + b.x;
    r.y = a.y + b.y;
    r.width  = a.width;
    r.height = a.height;
    return r;
}

intersect :: inline (v: Vector2, r: Rect) -> bool {
    return r.x <= v.x && r.width  >= v.x
        && r.y <= v.y && r.height >= v.y;
}

overlaps :: inline (a: Rect, b:Rect) -> bool {
    return a.x1 <= b.x2 && a.x2 >= b.x1
        && a.y1 <= b.y2 && a.y2 >= b.y1;
}

Point2 :: struct {
    x, y: s32;
}

xy :: make_point2;
make_point2 :: (x: s32) -> Point2 {
    return .{x, x};
}
make_point2 :: (x: s32, y: s32) -> Point2 {
    return .{x, y};
}

operator - :: (a: Point2) -> Point2 {
    return .{-a.x, -a.y};
}

operator / :: (a: Point2, b: s32) -> Point2 {
    return .{a.x / b, a.y / b};
}

operator / :: (a: s32, b: Point2) -> Point2 {
    return .{a / b.x, a / b.y};
}

Recti :: struct {
    x, y:          s32;
    width, height: s32;

#place x;
    position: Point2 = ---;
#place width;
    size: Point2 = ---;
}

intersect :: inline (p: Point2, r: Recti) -> bool {
    return r.x <= p.x && r.width  >= p.x &&
           r.y <= p.y && r.height >= p.y;
}

angle_to :: inline (a: Vector2, b: Vector2) -> float #must {
    return tatan2(b.y-a.y, b.x-a.x);
}

from_angle :: inline (theta: float) -> Vector2 #must {
    return .{tcos(theta), tsin(theta)};
}

from_angle :: inline (theta: float, length: float) -> Vector2 #must {
    return from_angle(theta) * length;
}

side_of_line :: inline (p: Vector2, a: Vector2, b: Vector2) -> float #must {
    return (p.x - a.x) * (a.y - b.y) + (p.y - a.y) * (b.x - a.x);
}

is_on_left_side_of_line :: inline (p: Vector2, a: Vector2, b: Vector2) -> bool #must {
    return (p.x - a.x) * (b.y - a.y) < (p.y - a.y) * (b.x - a.x);
}

distance_to_line :: inline (p: Vector2, a: Vector2, b: Vector2) -> float #must {
    perp := Vector2.{a.y - b.y, b.x - a.x};
    return abs((p.x - a.x) * perp.x + (p.y - a.y) * perp.y) / length(perp);
}

// This doesn't give the actual distance to the line, but it's fast and useful for sorting.
distance_to_line_fast :: inline (p: Vector2, a: Vector2, b: Vector2) -> float {
    return abs((p.x - a.x) * (-b.y + a.y) + (p.y - a.y) * (b.x - a.x));
}

ortho_project :: inline (direction: Vector2, v: Vector2) -> Vector2 {
    normalize_or_zero(*direction);
    return direction * dot(v, direction);
}

ortho_project :: inline (a: Vector2, b: Vector2, v: Vector2) -> Vector2 {
    return inline ortho_project(b - a, v);
}

// @Note(sushi): The determinant in all intersect_line procedures are the
//  winding direction of the collision.
intersect_line :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool, float {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return false, 0; // lines are collinear

    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    ac := c - a;                      // direction of a to c
    u  := cross(ac, ab) * determinant;
    t  := cross(ac, cd) * determinant;
    return u >= 0 && u <= 1 && t >= 0 && t <= 1, determinant; // all true if segments are intersecting
}

intersect_line_pos :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool, Vector2, float {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return false, .{}, 0; // lines are collinear

    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    ac := c - a;                      // direction of a to c
    u  := cross(ac, ab) * determinant;
    t  := cross(ac, cd) * determinant;
    if u < 0 || u > 1 || t < 0 || t > 1  return false, .{}, 0; // segments aren't intersecting

    cd.x = a.x + t * ab.x;
    cd.y = a.y + t * ab.y;
    return true, cd, determinant;
}

// returns the time of impact of a ray
intersect_line_toi :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float, float {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return 1, 0; // lines are collinear

    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    ac := c - a;                      // direction of a to c
    u  := cross(ac, ab) * determinant;
    t  := cross(ac, cd) * determinant;
    if u < 0 || u > 1 || t < 0 || t > 1  return 1, 0; // segments aren't intersecting

    return t, determinant;
}

// returns the time of impact of a ray with success
intersect_line_toi_success :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool, float, float {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return false, 1, 0; // lines are collinear

    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    ac := c - a;                      // direction of a to c
    u  := cross(ac, ab) * determinant;
    t  := cross(ac, cd) * determinant;
    return u >= 0 && u <= 1 && t >= 0 && t <= 1, t, determinant;
}

Circle :: struct {
    using position: Vector2;
    radius:         float;
}

Polygon :: struct (N: int) {
    using position: Vector2;
    angle:          float;
    vertices:   [N] Vector2;
    points:     [N] Vector2;
}

Triangle :: Polygon(3);
OBB      :: Polygon(4);
Pentagon :: Polygon(5);
Hexagon  :: Polygon(6);
Septagon :: Polygon(7);
Octagon  :: Polygon(8);

Polygon_Winding :: enum {
    Clockwise;
    Counter_Clockwise;
}

Edge :: struct {
    distance: float;
    normal:   Vector2;
    index:    int;
}

create_obb :: (position: Vector2, extents: Vector2, angle: float = 0) -> OBB {
    // @Todo(sushi): Rotate the OBB.
    obb: OBB = ---;
    obb.position = position;
    obb.angle    = angle;
    obb.vertices[0].x = -extents.x; obb.vertices[0].y = -extents.y;
    obb.vertices[1].x = -extents.x; obb.vertices[1].y = +extents.y;
    obb.vertices[2].x = +extents.x; obb.vertices[2].y = +extents.y;
    obb.vertices[3].x = +extents.x; obb.vertices[3].y = -extents.y;
    memcpy(obb.points.data, obb.vertices.data, obb.vertices.count * size_of(Vector2));
    return obb;
}

create_regular_pentagon :: (position: Vector2, radius: float, angle: float = 0, rotation: float = 0) -> Pentagon {
    TAU_OVER_5 :: TAU / 5;
    pentagon: Pentagon;
    pentagon.position = position;
    pentagon.angle    = angle;
    current_rotation := rotation + PI;
    for 0..4 {
        pentagon.vertices[it].x = sin(current_rotation) * radius;
        pentagon.vertices[it].y = cos(current_rotation) * radius;
        current_rotation += TAU_OVER_5;
    }
    memcpy(pentagon.points.data, pentagon.vertices.data, pentagon.vertices.count * size_of(Vector2));
    return pentagon;
}
