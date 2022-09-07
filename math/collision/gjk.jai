triple_product :: (a: Vector2, b: Vector2, c: Vector2) -> Vector2 #must {
    r: Vector2 = ---;
    ac := dot(a, c);
    bc := dot(b, c);
    r.x = b.x * ac - a.x * bc;
    r.y = b.y * ac - a.y * bc;
    return r;
}

support :: inline (shape_a: $A, shape_b: $B, direction: Vector2) -> Vector2 #must {
    return support(shape_a, direction) - support(shape_b, -direction);
}

support :: (using circle: *Circle, direction: Vector2) -> Vector2 #must {
    return position + radius * unit_vector(direction);
}

support :: (using polygon: *Polygon($N), direction: Vector2) -> Vector2 #must #no_abc {
    max_product := dot(direction, points[0]);
    index: int;
    for 1..N-1 {
        product := dot(direction, points[it]);
        if product > max_product {
            max_product = product;
            index = it;
        }
    }
    return points[index];
}

gjk :: (shape_a: $A, shape_b: $B) -> bool #must #no_abc {
    index: int;
    a, b, c, d, ao, ab, ac, ab_perp, ac_perp: Vector2 = ---;
    simplex: [3] Vector2;

    d = shape_a.position - shape_b.position;

    if d.x == 0 && d.y == 0  d.x = 1.0;

    a = support(shape_a, shape_b, d);
    if dot(a, d) <= 0  return false;
    simplex[0] = a;

    d = -a;

    while true {
        index += 1;
        a = support(shape_a, shape_b, d);
        if dot(a, d) <= 0  return false;
        simplex[index] = a;
        ao = -a;

        if index < 2 {
            b = simplex[0];
            ab = b - a;                     // from point A to B
            d = triple_product(ab, ao, ab); // normal to AB towards origin
            if length_squared(d) == 0  d = perpendicular(ab);
            continue;
        }

        b  = simplex[1];
        c  = simplex[0];
        ab = b - a; // from point A to B
        ac = c - a; // from point A to C

        ac_perp = triple_product(ab, ac, ac);
        if dot(ac_perp, ao) >= 0 {
            d = ac_perp;
        } else {
            ab_perp = triple_product(ac, ab, ab);
            if dot(ab_perp, ao) < 0  return true;

            simplex[0] = simplex[1];
            d = ab_perp;
        }

        simplex[1] = simplex[2];
        index -= 1;
    }

    return false;
}

gjk_intersect :: (shape_a: $A, shape_b: $B, $max_iterations := 32, $epsilon := 0.000_001) -> Vector2, bool #must #no_abc {
    index: int;
    a, b, c, direction, ao, ab, ac, ab_perp, ac_perp: Vector2 = ---;
    simplex: [3] Vector2;

    direction = shape_a.position - shape_b.position;

    if direction.x == 0 && direction.y == 0  direction.x = 1.0;

    a = support(shape_a, shape_b, direction);
    if dot(a, direction) <= 0  return .{}, false;
    simplex[0] = a;

    direction = -a;

    collided: bool;
    while true {
        index += 1;
        a = support(shape_a, shape_b, direction);
        if dot(a, direction) <= 0  return .{}, false;
        simplex[index] = a;
        ao = -a;

        if index < 2 {
            b = simplex[0];
            ab = b - a; // from point A to B
            direction = triple_product(ab, ao, ab); // normal to AB towards origin
            if length_squared(direction) == 0  direction = perpendicular(ab);
            continue;
        }

        b  = simplex[1];
        c  = simplex[0];
        ab = b - a; // from point A to B
        ac = c - a; // from point A to C

        ac_perp = triple_product(ab, ac, ac);
        if dot(ac_perp, ao) >= 0 {
            direction = ac_perp;
        } else {
            ab_perp = triple_product(ac, ab, ab);
            if dot(ab_perp, ao) < 0 {
                collided = true;
                break;
            }

            simplex[0] = simplex[1];
            direction = ab_perp;
        }

        simplex[1] = simplex[2];
        index -= 1;
    }

    if !collided  return .{}, false;

    epa0 := (simplex[1].x - simplex[0].x) * (simplex[1].y - simplex[0].y);
    epa1 := (simplex[2].x - simplex[1].x) * (simplex[2].y - simplex[1].y);
    epa2 := (simplex[0].x - simplex[2].x) * (simplex[0].y - simplex[2].y);

    winding: Polygon_Winding = ---;
    if epa0 + epa1 + epa2 >= 0 {
        winding = .Clockwise;
    } else {
        winding = .Counter_Clockwise;
    }

    edge:     Edge  = ---;
    distance: float = ---;
    for 0..max_iterations-1 {
        if winding == {
        case .Clockwise;         edge = find_closest_edge(simplex, .Clockwise);
        case .Counter_Clockwise; edge = find_closest_edge(simplex, .Counter_Clockwise);
        }
        a        = support(shape_a, shape_b, edge.normal);
        distance = dot(a, edge.normal);

        if abs(distance - edge.distance) <= epsilon {
            return edge.normal * distance, true;
        } else {
            simplex[edge.index] = a;
        }
    }

    return .{}, false;
}

find_closest_edge :: inline (simplex: [$N] Vector2, $winding: Polygon_Winding) -> Edge {
    closest_edge: Edge = ---;
    line:         Vector2 = ---;
    normal:       Vector2 = ---;
    distance:     float   = ---;
    for 0..N-1 {
        line = simplex[it % N] - simplex[it];
        #if winding == .Clockwise {
            normal.x =  line.y;
            normal.y = -line.x;
        } else #if winding == .Counter_Clockwise {
            normal.x = -line.y;
            normal.y =  line.x;
        }
        normalize_or_zero(*normal);

        distance = dot(normal, simplex[0]);
        if distance < closest_edge.distance {
            closest_edge.distance = distance;
            closest_edge.normal   = normal;
            closest_edge.index    = it;
        }
    }
    return closest_edge;
}

test_gjk :: () {
    #import "Random";

    random_seed(1);

    jostle :: (a: Vector2) -> Vector2 {
        r: Vector2 = ---;
        r.x = a.x + random_get_within_range(-0.1, 0.1);
        r.y = a.y + random_get_within_range(-0.1, 0.1);
        return r;
    }

    base_a := Vector2.[
        .{ 4.0, 11.0 },
        .{ 5.0, 5.0 },
        .{ 9.0, 9.0 },
    ];
    base_b := Vector2.[
        .{ 4.0, 11.0 },
        .{ 5.0, 5.0 },
        .{ 9.0, 9.0 },
    ];

    a: Triangle;
    b: Triangle;

    TOTAL_ITERATIONS :: 100;
    failing_cases: int;

    for 0..TOTAL_ITERATIONS-1 {
        for 0..2 {
            a.points[it] = jostle(base_a[it]);
            b.points[it] = jostle(base_b[it]);
        }

        intersection, success := gjk_intersect(*a, *b);
        if !success {
            info(#string END
Found failing case:
 > {%, %}, {%, %}, {%, %}
 > {%, %}, {%, %}, {%, %}
END,
            a.points[0].x, a.points[0].y, a.points[1].x, a.points[1].y, a.points[2].x, a.points[2].y,
            b.points[0].x, b.points[0].y, b.points[1].x, b.points[1].y, b.points[2].x, b.points[2].y);
            failing_cases += 1;
        } else {
            info("Intersection: %", intersection);
        }
    }

    info("Failed % / % GJK test cases.", failing_cases, TOTAL_ITERATIONS);
}
