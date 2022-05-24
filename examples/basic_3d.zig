const std = @import("std");
const sdl = @import("sdl");
const jok = @import("jok");
const gfx = jok.gfx.@"3d";
const font = jok.gfx.@"2d".font;

var camera: gfx.Camera = undefined;
var renderer: gfx.Renderer = undefined;
var cube: gfx.zmesh.Shape = undefined;

fn init(ctx: *jok.Context) anyerror!void {
    std.log.info("game init", .{});

    gfx.zmesh.init(ctx.default_allocator);
    const size = ctx.getFramebufferSize();

    camera = gfx.Camera.fromPositionAndTarget(
        .{
            .perspective = .{
                .fov = std.math.pi / 4.0,
                .aspect_ratio = @intToFloat(f32, size.w) / @intToFloat(f32, size.h),
                .near = 0.1,
                .far = 100,
            },
        },
        gfx.zmath.f32x4(0, 1, -2, 1),
        gfx.zmath.f32x4(0, 0, 0, 0),
        null,
    );
    renderer = gfx.Renderer.init(ctx.default_allocator);
    cube = gfx.zmesh.Shape.initCube();
}

fn loop(ctx: *jok.Context) anyerror!void {
    // camera movement
    const distance = ctx.delta_tick * 2;
    if (ctx.isKeyPressed(.w)) {
        camera.move(.forward, distance);
    }
    if (ctx.isKeyPressed(.s)) {
        camera.move(.backward, distance);
    }
    if (ctx.isKeyPressed(.a)) {
        camera.move(.left, distance);
    }
    if (ctx.isKeyPressed(.d)) {
        camera.move(.right, distance);
    }
    if (ctx.isKeyPressed(.left)) {
        camera.rotate(0, -std.math.pi / 180.0);
    }
    if (ctx.isKeyPressed(.right)) {
        camera.rotate(0, std.math.pi / 180.0);
    }
    if (ctx.isKeyPressed(.up)) {
        camera.rotate(std.math.pi / 180.0, 0);
    }
    if (ctx.isKeyPressed(.down)) {
        camera.rotate(-std.math.pi / 180.0, 0);
    }

    while (ctx.pollEvent()) |e| {
        switch (e) {
            .keyboard_event => |key| {
                if (key.trigger_type == .up) {
                    switch (key.scan_code) {
                        .escape => ctx.kill(),
                        else => {},
                    }
                }
            },
            .quit_event => ctx.kill(),
            else => {},
        }
    }

    const model = gfx.zmath.mul(
        gfx.zmath.translation(-0.5, -0.5, -0.5),
        gfx.zmath.rotationY(@floatCast(f32, ctx.tick) * std.math.pi / 3.0),
    );

    try ctx.renderer.setColorRGB(77, 77, 77);
    try ctx.renderer.clear();
    renderer.clearVertex(true);
    try renderer.appendVertex(
        ctx.renderer,
        model,
        &camera,
        cube.indices,
        cube.positions,
        null,
        null,
    );
    try renderer.drawWireframe(ctx.renderer, sdl.Color.white);

    _ = try font.debugDraw(
        ctx.renderer,
        .{
            .pos = .{ .x = 300, .y = 0 },
            .color = sdl.Color.green,
        },
        "camera pos: {any}",
        .{camera.position},
    );
}

fn quit(ctx: *jok.Context) void {
    _ = ctx;
    std.log.info("game quit", .{});

    cube.deinit();
    gfx.zmesh.deinit();
    renderer.deinit();
}

pub fn main() anyerror!void {
    try jok.run(.{
        .initFn = init,
        .loopFn = loop,
        .quitFn = quit,
    });
}
