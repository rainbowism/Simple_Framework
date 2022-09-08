Circle :: struct {
    using position: Vector2;
    angle:          Vector2;
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
