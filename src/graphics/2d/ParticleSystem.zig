const std = @import("std");
const assert = std.debug.assert;
const sdl = @import("sdl");
const Vector = @import("Vector.zig");
const Sprite = @import("Sprite.zig");
const SpriteBatch = @import("SpriteBatch.zig");
const Self = @This();

const default_effects_capacity = 10;

/// Memory allocator
allocator: std.mem.Allocator,

/// Particle effects
effects: std.ArrayList(Effect),

/// Create particle effect system/manager
pub fn init(allocator: std.mem.Allocator) !*Self {
    var self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .effects = try std.ArrayList(Effect)
            .initCapacity(allocator, default_effects_capacity),
    };
    return self;
}

/// Destroy particle effect system/manager
pub fn deinit(self: *Self) void {
    for (self.effects.items) |e| {
        e.deinit();
    }
    self.effects.deinit();
    self.allocator.destroy(self);
}

/// Update system
pub fn update(self: *Self, delta_time: f32) void {
    var i: usize = 0;
    while (i < self.effects.items.len) {
        var e = &self.effects.items[i];
        e.update(delta_time);
        if (e.isOver()) {
            _ = self.effects.swapRemove(i);
        } else {
            i += 1;
        }
    }
}

/// Draw effects
pub fn draw(self: Self, sprite_batch: *SpriteBatch) !void {
    for (self.effects.items) |e| {
        try e.draw(sprite_batch);
    }
}

/// Add effect
pub fn addEffect(
    self: *Self,
    random: std.rand.Random,
    max_particle_num: u32,
    emit_fn: Effect.ParticleEmitFn,
    origin: Vector,
    effect_duration: f32,
    gen_amount: u32,
    burst_freq: f32,
) !void {
    var effect = try Effect.init(
        self.allocator,
        random,
        max_particle_num,
        emit_fn,
        origin,
        effect_duration,
        gen_amount,
        burst_freq,
    );
    errdefer effect.deinit();
    try self.effects.append(effect);
}

/// Represent a particle effect
pub const Effect = struct {
    pub const ParticleEmitFn = *const fn (
        random: std.rand.Random,
        origin: Vector,
    ) Particle;

    /// Random number generator
    random: std.rand.Random,

    /// All particles
    particles: std.ArrayList(Particle),

    /// Particle emitter
    emit_fn: ParticleEmitFn,

    /// Origin of particle
    origin: Vector,

    /// Effect duration
    effect_duration: f32,

    /// New particle amount per burst
    gen_amount: u32,

    /// Burst frequency
    burst_freq: f32,

    /// Burst countdown
    burst_countdown: f32,

    /// Particle effect initialization
    pub fn init(
        allocator: std.mem.Allocator,
        random: std.rand.Random,
        max_particle_num: u32,
        emit_fn: ParticleEmitFn,
        origin: Vector,
        effect_duration: f32,
        gen_amount: u32,
        burst_freq: f32,
    ) !Effect {
        assert(max_particle_num > 0);
        assert(effect_duration > 0);
        assert(gen_amount > 0);
        assert(burst_freq > 0);
        assert(effect_duration > burst_freq);
        return Effect{
            .random = random,
            .particles = try std.ArrayList(Particle)
                .initCapacity(allocator, max_particle_num),
            .emit_fn = emit_fn,
            .origin = origin,
            .effect_duration = effect_duration,
            .gen_amount = gen_amount,
            .burst_freq = burst_freq,
            .burst_countdown = burst_freq,
        };
    }

    pub fn deinit(self: Effect) void {
        self.particles.deinit();
    }

    /// Update effect
    pub fn update(self: *Effect, delta_time: f32) void {
        if (self.effect_duration > 0) {
            self.effect_duration -= delta_time;
            self.burst_countdown -= delta_time;
            if (self.effect_duration >= 0 and
                self.burst_countdown <= 0 and
                self.particles.items.len < self.particles.capacity)
            {
                var i: u32 = 0;
                while (i < self.gen_amount) : (i += 1) {
                    // Generate new particle
                    self.particles.appendAssumeCapacity(
                        self.emit_fn(self.random, self.origin),
                    );
                    if (self.particles.items.len == self.particles.capacity) break;
                }
            }
        }

        // Update each particles' status
        var i: usize = 0;
        while (i < self.particles.items.len) {
            var p = &self.particles.items[i];
            p.update(delta_time);
            if (p.isDead()) {
                _ = self.particles.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Draw the effect
    pub fn draw(self: Effect, sprite_batch: *SpriteBatch) !void {
        for (self.particles.items) |p| {
            try p.draw(sprite_batch);
        }
    }

    /// If effect is over
    pub fn isOver(self: Effect) bool {
        return self.effect_duration <= 0 and self.particles.items.len == 0;
    }

    /// Bulitin particle emitter: fire
    pub fn FireEmitter(
        comptime _radius: f32,
        comptime _age_initial: f32,
        comptime _color_initial: sdl.Color,
        comptime _color_final: sdl.Color,
        comptime _color_fade_age: f32,
    ) type {
        return struct {
            pub var sprite: ?Sprite = null;
            pub var radius = _radius;
            pub var age_initial = _age_initial;
            pub var color_initial = _color_initial;
            pub var color_final = _color_final;
            pub var color_fade_age = _color_fade_age;

            pub fn emit(random: std.rand.Random, origin: Vector) Particle {
                const offset = Vector.new(
                    random.float(f32) * radius * @cos(random.float(f32) * std.math.tau),
                    random.float(f32) * radius * @sin(random.float(f32) * std.math.tau),
                );

                assert(color_fade_age < age_initial);
                return Particle{
                    .sprite = sprite.?,
                    .age = age_initial,
                    .pos = origin.add(offset),
                    .move_speed = Vector.new(-offset.x() * 0.5, 0),
                    .move_acceleration = Vector.new(0, -random.float(f32) * 200),
                    .move_damp = 0.96,
                    .scale = 0.5,
                    .scale_speed = -0.1,
                    .scale_acceleration = 0.0,
                    .scale_max = 1.0,
                    .color_initial = color_initial,
                    .color_final = color_final,
                    .color_fade_age = color_fade_age,
                };
            }
        };
    }
};

/// Represent a particle
pub const Particle = struct {
    /// Sprite of particle
    sprite: Sprite,

    /// Life of particle
    age: f32,

    /// Position changing
    pos: Vector,
    move_speed: Vector,
    move_acceleration: Vector,
    move_damp: f32,

    /// Rotation changing
    angle: f32 = 0,
    rotation_speed: f32 = 0,
    rotation_damp: f32 = 1,

    /// Scale changing
    scale: f32 = 1,
    scale_speed: f32 = 0,
    scale_acceleration: f32 = 0,
    scale_max: f32 = 1,

    /// Color changing
    color: sdl.Color = undefined,
    color_initial: sdl.Color = sdl.Color.white,
    color_final: sdl.Color = sdl.Color.white,
    color_fade_age: f32 = 0,

    fn updatePos(self: *Particle, delta_time: f32) void {
        assert(self.move_damp >= 0 and self.move_damp <= 1);
        self.move_speed = self.move_speed.scale(self.move_damp);
        self.move_speed = self.move_speed.add(self.move_acceleration.scale(delta_time));
        self.pos = self.pos.add(self.move_speed.scale(delta_time));
    }

    fn updateRotation(self: *Particle, delta_time: f32) void {
        assert(self.rotation_damp >= 0 and self.rotation_damp <= 1);
        self.rotation_speed *= self.rotation_damp;
        self.angle += self.rotation_speed * delta_time;
    }

    fn updateScale(self: *Particle, delta_time: f32) void {
        assert(self.scale_max > 0);
        self.scale_speed += self.scale_acceleration * delta_time;
        self.scale += self.scale_speed * delta_time;
        self.scale = std.math.clamp(self.scale, 0.0, self.scale_max);
    }

    fn lerpColorElement(v1: u8, v2: u8, c1: f32, c2: f32) u8 {
        return @floatToInt(u8, @intToFloat(f32, v1) * c1 + @intToFloat(f32, v2) * c2);
    }

    fn updateColor(self: *Particle) void {
        if (self.age > self.color_fade_age) {
            self.color = self.color_initial;
        } else {
            assert(self.color_fade_age > 0);
            const c1 = std.math.max(self.age, 0.0) / self.color_fade_age;
            const c2 = 1.0 - c1;
            self.color = .{
                .r = lerpColorElement(self.color_initial.r, self.color_final.r, c1, c2),
                .g = lerpColorElement(self.color_initial.g, self.color_final.g, c1, c2),
                .b = lerpColorElement(self.color_initial.b, self.color_final.b, c1, c2),
                .a = lerpColorElement(self.color_initial.a, self.color_final.a, c1, c2),
            };
        }
    }

    /// If particle is dead
    pub inline fn isDead(self: Particle) bool {
        return self.age <= 0;
    }

    /// Update particle's status
    pub fn update(self: *Particle, delta_time: f32) void {
        if (self.age <= 0) return;
        self.age -= delta_time;
        self.updatePos(delta_time);
        self.updateRotation(delta_time);
        self.updateScale(delta_time);
        self.updateColor();
    }

    /// Draw particle
    pub fn draw(self: Particle, sprite_batch: *SpriteBatch) !void {
        try sprite_batch.drawSprite(
            self.sprite,
            .{
                .pos = .{ .x = self.pos.x(), .y = self.pos.y() },
                .tint_color = self.color,
                .scale_w = self.scale,
                .scale_h = self.scale,
                .rotate_degree = self.angle,
                .anchor_point = .{ .x = 0.5, .y = 0.5 },
                .depth = 0,
            },
        );
    }
};
