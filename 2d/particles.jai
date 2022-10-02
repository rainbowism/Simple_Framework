Particle_Material :: struct {
    shader: *Shader;
}

Particle_Emitter :: struct() {
    particles: Bucket_Array(Particle, 128, true);
    texture: Texture;
    spawn_particle: Particle_Spawn_Callback;
    sim_particle: Particle_Sim_Callback;
    emitting := true;
    particles_per_second: float = 100;
    interval_per_particle: float = 0.01;
    origin: Vector2;
    position: Vector2;
    velocity: Vector2;
    acceleration: Vector2;
    elapsed: float;
    remainder: float;
    emitted: s64;
}

Particle :: struct {
    position: Vector2 = ---;
    velocity: Vector2 = ---;
    acceleration: Vector2;
    base_scale: Vector2 = ---;
    scale: Vector2 = ---;
    elapsed: float = ---;
    lifetime: float = ---;
    color: Color = ---;
}

Particle_Spawn_Callback :: #type (emitter: *Particle_Emitter);
Particle_Sim_Callback :: #type (particle: *Particle, delta: float);

create_emitter :: (
    texture: Texture,
    particles_per_second: float = 100,
    $spawn_callback: Particle_Spawn_Callback = spawn_particle,
    $sim_callback: Particle_Sim_Callback = sim_particle
) -> *Particle_Emitter {
    emitter := New(Particle_Emitter);
    emitter.texture = texture;
    emitter.spawn_particle = spawn_callback;
    emitter.sim_particle = sim_callback;
    emitter.particles_per_second = particles_per_second;
    emitter.interval_per_particle = 1.0 / particles_per_second;
    emitter.origin = xy(cast(float) texture.width, cast(float) texture.height) * 0.5;
    add_bucket(*emitter.particles);
    return emitter;
}

update_emitter :: (emitter: *Particle_Emitter, delta: float) {
    for particle: emitter.particles {
        emitter.sim_particle(particle, delta);

        if particle.elapsed > particle.lifetime  remove;
    }

    emitter.elapsed += delta;
    emitter.remainder += delta;

    if emitter.emitting {
        while emitter.remainder > emitter.interval_per_particle {
            emitter.remainder -= emitter.interval_per_particle;
            emitter.spawn_particle(emitter);
        }
    } else {
        // @Todo(sushi): Free the emitter.
    }
}

draw_emitter :: (emitter: *Particle_Emitter, $additive := false) {
    #if additive {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        defer glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    for particle: emitter.particles {
        draw_texture(emitter.texture, particle.position, particle.scale, tint = particle.color, origin = emitter.origin);
    }
    batch_draw();
}

#scope_file

spawn_particle :: (emitter: *Particle_Emitter) {
    locator, particle := bucket_array_add(*emitter.particles, .{});
    particle.position = emitter.position;
    particle.velocity = emitter.velocity;
    theta := get_single_float(41935, emitter.emitted) * TAU;
    particle.velocity.x += 200 * cos(theta);
    particle.velocity.y += 200 * sin(theta);
    particle.scale.x = get_single_float(41935, emitter.emitted + 1) * 0.1 + 0.05;
    particle.scale.y = particle.scale.x;
    particle.elapsed = 0.0;
    particle.lifetime = get_single_float(41935, emitter.emitted + 1) * 1.5 + 1.5;
    particle.color = Colors.White;
    emitter.emitted += 1;
    emitter.sim_particle(particle, emitter.remainder);
    return particle;
}

sim_particle :: (using particle: *Particle, delta: float) {
    // @Todo(sushi): Add a velocity gradient function so we have consistent values.
    //  Or we can simulate these only on physics ticks and interpolate them?
    velocity += acceleration * delta;
    position += velocity * delta;
    elapsed  += delta;
}

#import "Bucket_Array";
#import "GL";
