Particle_Material :: struct {
    shader: *Shader;
}

Particle_Emitter :: struct(additive := false) {
    particles: Bucket_Array(Particle, 128, true);
    texture: Texture;
    emitting := true;
    particles_per_second: float = 100;
    interval_per_particle: float = 0.01;
    origin: Vector2;
    position: Vector2;
    velocity: Vector2;
    elapsed: float;
    remainder: float;
    emitted: s64;
}

Particle :: struct {
    position: Vector2 = ---;
    velocity: Vector2 = ---;
    scale: float = ---;
    elapsed: float = ---;
    lifetime: float = ---;
    color: Color = ---;
}

create_emitter :: (texture: Texture, particles_per_second: float = 100, $additive := false) -> *Particle_Emitter(additive) {
    emitter := New(Particle_Emitter(additive));
    emitter.texture = texture;
    emitter.particles_per_second = particles_per_second;
    emitter.interval_per_particle = 1.0 / particles_per_second;
    emitter.origin = xy(cast(float) texture.width, cast(float) texture.height) * 0.5;
    add_bucket(*emitter.particles);
    return emitter;
}

update_emitter :: (emitter: *Particle_Emitter, delta: float) {
    for particle: emitter.particles {
        sim_particle(particle, delta);

        if particle.elapsed > particle.lifetime  remove;
    }

    emitter.elapsed += delta;
    emitter.remainder += delta;

    if emitter.emitting {
        while emitter.remainder > emitter.interval_per_particle {
            emitter.remainder -= emitter.interval_per_particle;
            particle := spawn_particle(emitter);
            emitter.emitted += 1;
            sim_particle(particle, emitter.remainder);
        }
    } else {
        // @Todo(sushi): Free the emitter.
    }
}

draw_emitter :: (emitter: *Particle_Emitter) {
    #if emitter.additive {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    }
    for particle: emitter.particles {
        draw_texture(emitter.texture, particle.position, particle.scale, tint = particle.color, origin = emitter.origin);
    }
    batch_draw();
    #if emitter.additive {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
}

#scope_file

spawn_particle :: (emitter: *Particle_Emitter) -> *Particle {
    locator, particle := bucket_array_add(*emitter.particles, .{});
    particle.position = emitter.position;
    particle.velocity = emitter.velocity;
    theta := get_single_float(41935, emitter.emitted) * TAU;
    particle.velocity.x += 200 * cos(theta);
    particle.velocity.y += 200 * sin(theta);
    particle.scale = get_single_float(41935, emitter.emitted + 1) * 0.1 + 0.05;
    particle.elapsed = 0.0;
    particle.lifetime = get_single_float(41935, emitter.emitted + 1) * 1.5 + 1.5;
    particle.color = Colors.White;
    return particle;
}

sim_particle :: (particle: *Particle, delta: float) {
    particle.position += particle.velocity * delta;
    // @Todo(sushi): Add a velocity gradient function so we have consistent drag.
    particle.elapsed += delta;
}

#import "Bucket_Array";
#import "GL";
