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
    obb.vertices[0].x = position.x - extents.x; obb.vertices[0].y = position.y - extents.y;
    obb.vertices[1].x = position.x + extents.x; obb.vertices[1].y = position.y - extents.y;
    obb.vertices[2].x = position.x + extents.x; obb.vertices[2].y = position.y + extents.y;
    obb.vertices[3].x = position.x - extents.x; obb.vertices[3].y = position.y + extents.y;
    info("%", obb.vertices.count);
    memcpy(obb.points.data, obb.vertices.data, obb.vertices.count * size_of(Vector2));
    return obb;
}

#import "Math";
#import "Math_Ext";
#load "collision/gjk.jai";
