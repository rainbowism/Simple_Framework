circle_intersect :: inline (a: Vector2, b: Vector2, radius: float) -> bool {
    return in_radius(a - b, radius);
}

in_radius :: inline (v: Vector2, radius: float) -> bool {
    return v.x * v.x + v.y * v.y >= radius * radius;
}

Rect :: struct {
    x, y:          float;
    width, height: float;
#place x;
    position: Vector2;
#place width;
    size: Vector2;
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
    return r.x <= v.x && r.width  >= v.x &&
           r.y <= v.y && r.height >= v.y;
}

Point2 :: struct {
    x, y: s32;
}

xy :: make_point2;
make_point2 :: (x: s32) -> Point2 {
    p: Point2 = ---;
    p.x = x;
    p.y = x;
    return p;
}
make_point2 :: (x: s32, y: s32) -> Point2 {
    p: Point2 = ---;
    p.x = x;
    p.y = y;
    return p;
}

operator - :: (a: Point2) -> Point2 {
    r: Point2 = ---;
    r.x = -a.x;
    r.y = -a.y;
    return r;
}

operator / :: (a: Point2, b: s32) -> Point2 {
    r: Point2 = ---;
    r.x = a.x / b;
    r.y = a.y / b;
    return r;
}

operator / :: (a: s32, b: Point2) -> Point2 {
    r: Point2 = ---;
    r.x = a / b.x;
    r.y = a / b.y;
    return r;
}

Recti :: struct {
    x, y:          s32;
    width, height: s32;
#place x;
    position: Point2;
#place width;
    size: Point2;
}

intersect :: inline (p: Point2, r: Recti) -> bool {
    return r.x <= p.x && r.width  >= p.x &&
           r.y <= p.y && r.height >= p.y;
}

// @Note(sushi): The determinant in all intersect_line procedures are the
//  winding direction of the collision.
intersect_line :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool, float {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return false, 0; // lines are collinear

    ac          := c - a;             // direction of a to c
    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    u := cross(ac, ab) * determinant;
    t := cross(ac, cd) * determinant;
    return u >= 0 && u <= 1 && t >= 0 && t <= 1, determinant; // all true if segments are intersecting
}

intersect_line_pos :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool, Vector2, float {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return false, .{}, 0; // lines are collinear

    ac          := c - a;             // direction of a to c
    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    u := cross(ac, ab) * determinant;
    t := cross(ac, cd) * determinant;
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

    ac          := c - a;             // direction of a to c
    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    u := cross(ac, ab) * determinant;
    t := cross(ac, cd) * determinant;
    if u < 0 || u > 1 || t < 0 || t > 1  return 1, 0; // segments aren't intersecting

    return t, determinant;
}

side_of_line :: (position: Vector2, a: Vector2, b: Vector2) -> float {
    product := (position.x - a.x) * (-b.y + a.y) + (position.y - a.y) * (b.x - a.x);
    if product < 0  return -1;
    if product > 0  return  1;
    return 0;
}

distance_to_line :: (position: Vector2, a: Vector2, b: Vector2) -> float {
    perp: Vector2 = ---;
    perp.x = -b.y + a.y;
    perp.y =  b.x - a.x;
    return abs((position.x - a.x) * perp.x + (position.y - a.y) * perp.y) / length(perp);
}

// This doesn't give the actual distance to the line, but it's fast and useful for sorting.
distance_to_line_fast :: (position: Vector2, a: Vector2, b: Vector2) -> float {
    return abs((position.x - a.x) * (-b.y + a.y) + (position.y - a.y) * (b.x - a.x));
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

#load "collision/gjk.jai";
