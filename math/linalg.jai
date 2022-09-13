intersect_line :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return false; // lines are collinear

    ac          := c - a;             // direction of a to c
    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    u := cross(ac, ab) * determinant;
    t := cross(ac, cd) * determinant;
    return u >= 0 && u <= 1 && t >= 0 && t <= 1; // all true if segments are intersecting
}

intersect_line_pos :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool, Vector2 {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return false, .{}; // lines are collinear

    ac          := c - a;             // direction of a to c
    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    u := cross(ac, ab) * determinant;
    t := cross(ac, cd) * determinant;
    if u < 0 || u > 1 || t < 0 || t > 1  return false, .{}; // segments aren't intersecting

    cd.x = a.x + t * ab.x;
    cd.y = a.y + t * ab.y;
    return true, cd;
}

// returns the time of impact of a ray
intersect_line_toi :: (a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float {
    ab := b - a; // direction of a to b
    cd := d - c; // direction of c to d

    determinant := cross(ab, cd);
    if determinant == 0  return 1; // lines are collinear

    ac          := c - a;             // direction of a to c
    determinant  = 1.0 / determinant; // cache `1.0 / determinant` for below
    u := cross(ac, ab) * determinant;
    t := cross(ac, cd) * determinant;
    if u < 0 || u > 1 || t < 0 || t > 1  return 1; // segments aren't intersecting

    return t;
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

#import "Math";
#import "Math_Ext";
#load "collision/gjk.jai";
