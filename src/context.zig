const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");
const bos = @import("build_options");
const config = @import("config.zig");
const jok = @import("jok.zig");
const sdl = jok.sdl;
const font = jok.font;
const imgui = jok.imgui;
const zaudio = jok.zaudio;
const zmesh = jok.zmesh;

const log = std.log.scoped(.jok);

/// Application context
pub const Context = struct {
    ctx: *anyopaque,
    vtable: struct {
        allocator: *const fn (ctx: *anyopaque) std.mem.Allocator,
        running: *const fn (ctx: *anyopaque) bool,
        seconds: *const fn (ctx: *anyopaque) f32,
        realSeconds: *const fn (ctx: *anyopaque) f64,
        deltaSeconds: *const fn (ctx: *anyopaque) f32,
        fps: *const fn (ctx: *anyopaque) f32,
        window: *const fn (ctx: *anyopaque) sdl.Window,
        renderer: *const fn (ctx: *anyopaque) sdl.Renderer,
        audioEngine: *const fn (ctx: *anyopaque) *zaudio.Engine,
        kill: *const fn (ctx: *anyopaque) void,
        toggleResizable: *const fn (ctx: *anyopaque, on_off: ?bool) void,
        toggleFullscreeen: *const fn (ctx: *anyopaque, on_off: ?bool) void,
        toggleAlwaysOnTop: *const fn (ctx: *anyopaque, on_off: ?bool) void,
        getWindowPosition: *const fn (ctx: *anyopaque) sdl.PointF,
        getWindowSize: *const fn (ctx: *anyopaque) sdl.PointF,
        getFramebufferSize: *const fn (ctx: *anyopaque) sdl.PointF,
        getAspectRatio: *const fn (ctx: *anyopaque) f32,
        getPixelRatio: *const fn (ctx: *anyopaque) f32,
        isKeyPressed: *const fn (ctx: *anyopaque, key: sdl.Scancode) bool,
        getMouseState: *const fn (ctx: *anyopaque) sdl.MouseState,
        setMousePosition: *const fn (ctx: *anyopaque, xrel: f32, yrel: f32) void,
        displayStats: *const fn (ctx: *anyopaque, opt: DisplayStats) void,
    },

    /// Get meomry allocator
    pub fn allocator(self: Context) std.mem.Allocator {
        return self.vtable.allocator(self.ctx);
    }

    /// Get application running status
    pub fn running(self: Context) bool {
        return self.vtable.running(self.ctx);
    }

    /// Get running seconds of application
    pub fn seconds(self: Context) f32 {
        return self.vtable.seconds(self.ctx);
    }

    /// Get running seconds of application (double precision)
    pub fn realSeconds(self: Context) f64 {
        return self.vtable.realSeconds(self.ctx);
    }

    /// Get delta time between frames
    pub fn deltaSeconds(self: Context) f32 {
        return self.vtable.deltaSeconds(self.ctx);
    }

    /// Get FPS of application
    pub fn fps(self: Context) f32 {
        return self.vtable.fps(self.ctx);
    }

    /// Get SDL window
    pub fn window(self: Context) sdl.Window {
        return self.vtable.window(self.ctx);
    }

    /// Get SDL renderer
    pub fn renderer(self: Context) sdl.Renderer {
        return self.vtable.renderer(self.ctx);
    }

    /// Get audio engine
    pub fn audioEngine(self: Context) *zaudio.Engine {
        return self.vtable.audioEngine(self.ctx);
    }

    /// Kill application
    pub fn kill(self: Context) void {
        return self.vtable.kill(self.ctx);
    }

    /// Toggle resizable
    pub fn toggleResizable(self: Context, on_off: ?bool) void {
        return self.vtable.toggleResizable(self.ctx, on_off);
    }

    /// Toggle fullscreen
    pub fn toggleFullscreeen(self: Context, on_off: ?bool) void {
        return self.vtable.toggleFullscreeen(self.ctx, on_off);
    }

    /// Toggle always-on-top
    pub fn toggleAlwaysOnTop(self: Context, on_off: ?bool) void {
        return self.vtable.toggleAlwaysOnTop(self.ctx, on_off);
    }

    /// Get position of window
    pub fn getWindowPosition(self: Context) sdl.PointF {
        return self.vtable.getWindowPosition(self.ctx);
    }

    /// Get size of window
    pub fn getWindowSize(self: Context) sdl.PointF {
        return self.vtable.getWindowSize(self.ctx);
    }

    /// Get size of framebuffer
    pub fn getFramebufferSize(self: Context) sdl.PointF {
        return self.vtable.getFramebufferSize(self.ctx);
    }

    /// Get aspect ratio of drawing area
    pub fn getAspectRatio(self: Context) f32 {
        return self.vtable.getAspectRatio(self.ctx);
    }

    /// Get pixel ratio
    pub fn getPixelRatio(self: Context) f32 {
        return self.vtable.getPixelRatio(self.ctx);
    }

    /// Get key status
    pub fn isKeyPressed(self: Context, key: sdl.Scancode) bool {
        return self.vtable.isKeyPressed(self.ctx, key);
    }

    /// Get mouse state
    pub fn getMouseState(self: Context) sdl.MouseState {
        return self.vtable.getMouseState(self.ctx);
    }

    /// Move mouse to given position (relative to window)
    pub fn setMousePosition(self: Context, xrel: f32, yrel: f32) void {
        return self.vtable.setMousePosition(self.ctx, xrel, yrel);
    }

    /// Display statistics
    pub fn displayStats(self: Context, opt: DisplayStats) void {
        return self.vtable.displayStats(self.ctx, opt);
    }
};

pub const DisplayStats = struct {
    movable: bool = false,
    collapsible: bool = false,
};

/// Context generator
pub fn JokContext(comptime cfg: config.Config) type {
    const AllocatorType = std.heap.GeneralPurposeAllocator(.{
        .safety = cfg.jok_mem_leak_checks,
        .verbose_log = cfg.jok_mem_detail_logs,
        .enable_memory_limit = true,
    });

    return struct {
        var gpa: AllocatorType = .{};

        // Application Context
        _ctx: Context = undefined,

        // Memory allocator
        _allocator: std.mem.Allocator = undefined,

        // Is running
        _running: bool = true,

        // Internal window
        _window: sdl.Window = undefined,

        // Renderer
        _renderer: sdl.Renderer = undefined,
        _is_software: bool = false,

        // Audio stuff
        _audio_engine: *zaudio.Engine = undefined,

        // Resizable mode
        _resizable: bool = undefined,

        // Fullscreen mode
        _fullscreen: bool = undefined,

        // Whether always on top
        _always_on_top: bool = undefined,

        // Elapsed time of game
        _seconds: f32 = 0,
        _seconds_real: f64 = 0,

        // Delta time between update/draw
        _delta_seconds: f32 = 0,

        // Frames stats
        _fps: f32 = 0,
        _pc_last: u64 = 0,
        _pc_accumulated: u64 = 0,
        _pc_freq: u64 = 0,
        _drawcall_count: u32 = 0,
        _triangle_count: u32 = 0,
        _frame_count: u32 = 0,
        _last_fps_refresh_time: f64 = 0,

        pub fn create() !*@This() {
            var _allocator = cfg.jok_allocator orelse gpa.allocator();
            var self = try _allocator.create(@This());
            self.* = .{};
            self._allocator = _allocator;
            self._ctx = self.context();

            // Check and print system info
            try self.checkSys();

            // Init SDL window and renderer
            try self.initSDL();

            // Init imgui
            imgui.sdl.init(self._ctx, cfg.jok_imgui_ini_file);

            // Init zmesh
            zmesh.init(self._allocator);

            // Init 2d and 3d modules
            try jok.j2d.init(self._allocator, self._renderer);
            try jok.j3d.init(self._allocator, self._renderer);

            // Init audio engine
            zaudio.init(self._allocator);
            self._audio_engine = try zaudio.Engine.create(null);

            // Init builtin debug font
            try font.DebugFont.init(self._allocator);
            if (cfg.jok_prebuild_atlas) |size| {
                _ = try font.DebugFont.getAtlas(self._ctx, size);
            }

            // Misc.
            self._pc_freq = sdl.c.SDL_GetPerformanceFrequency();
            self._pc_last = sdl.c.SDL_GetPerformanceCounter();
            return self;
        }

        pub fn destroy(self: *@This()) void {
            // Destroy builtin font data
            font.DebugFont.deinit();

            // Destroy audio engine
            self._audio_engine.destroy();
            zaudio.deinit();

            // Destroy 2d and 3d modules
            jok.j3d.deinit();
            jok.j2d.deinit();

            // Destroy zmesh
            zmesh.deinit();

            // Destroy imgui
            imgui.sdl.deinit();

            // Destroy window and renderer
            self.deinitSDL();

            // Destory self
            self._allocator.destroy(self);

            // Destory memory allocator
            if (gpa.deinit() == .leak) {
                @panic("jok: memory leaks happened!");
            }
        }

        /// Ticking of application
        pub fn tick(
            self: *@This(),
            comptime eventFn: *const fn (Context, sdl.Event) anyerror!void,
            comptime updateFn: *const fn (Context) anyerror!void,
            comptime drawFn: *const fn (Context) anyerror!void,
        ) void {
            while (sdl.pollNativeEvent()) |e| {
                _ = imgui.sdl.processEvent(e);
                const we = sdl.Event.from(e);
                if (cfg.jok_exit_on_recv_esc and we == .key_up and
                    we.key_up.scancode == .escape)
                {
                    kill(self);
                } else if (cfg.jok_exit_on_recv_quit and we == .quit) {
                    kill(self);
                } else {
                    eventFn(self._ctx, we) catch |err| {
                        log.err("Got error in `event`: {}", .{err});
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpStackTrace(trace.*);
                            break;
                        }
                    };
                }
            }

            self.internalLoop(updateFn, drawFn);
        }

        /// Internal game loop
        inline fn internalLoop(
            self: *@This(),
            comptime updateFn: *const fn (Context) anyerror!void,
            comptime drawFn: *const fn (Context) anyerror!void,
        ) void {
            const fps_pc_threshold: u64 = switch (cfg.jok_fps_limit) {
                .none => 0,
                .auto => if (self._is_software) @divTrunc(self._pc_freq, 30) else 0,
                .manual => |_fps| self._pc_freq / @as(u64, _fps),
            };
            const max_accumulated: u64 = self._pc_freq >> 1;

            // Update game
            if (fps_pc_threshold > 0) {
                while (true) {
                    const pc = sdl.c.SDL_GetPerformanceCounter();
                    self._pc_accumulated += pc - self._pc_last;
                    self._pc_last = pc;
                    if (self._pc_accumulated >= fps_pc_threshold) {
                        break;
                    }
                    if ((fps_pc_threshold - self._pc_accumulated) * 1000 > self._pc_freq) {
                        sdl.delay(1);
                    }
                }

                if (self._pc_accumulated > max_accumulated)
                    self._pc_accumulated = max_accumulated;

                // Perform as many update as we can, with fixed step
                var step_count: u32 = 0;
                const fps_delta_seconds: f32 = @floatCast(
                    @as(f64, @floatFromInt(fps_pc_threshold)) / @as(f64, @floatFromInt(self._pc_freq)),
                );
                while (self._pc_accumulated >= fps_pc_threshold) {
                    step_count += 1;
                    self._pc_accumulated -= fps_pc_threshold;
                    self._delta_seconds = fps_delta_seconds;
                    self._seconds += self._delta_seconds;
                    self._seconds_real += self._delta_seconds;

                    updateFn(self._ctx) catch |e| {
                        log.err("Got error in `update`: {}", .{e});
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpStackTrace(trace.*);
                            kill(self);
                            return;
                        }
                    };
                }
                assert(step_count > 0);

                // Set delta time between `draw`
                self._delta_seconds = @as(f32, @floatFromInt(step_count)) * fps_delta_seconds;
            } else {
                // Perform one update
                const pc = sdl.c.SDL_GetPerformanceCounter();
                self._delta_seconds = @floatCast(
                    @as(f64, @floatFromInt(pc - self._pc_last)) / @as(f64, @floatFromInt(self._pc_freq)),
                );
                self._pc_last = pc;
                self._seconds += self._delta_seconds;
                self._seconds_real += self._delta_seconds;

                updateFn(self._ctx) catch |e| {
                    log.err("Got error in `update`: {}", .{e});
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                        kill(self);
                        return;
                    }
                };
            }

            // Do rendering
            self._renderer.clear() catch unreachable;
            imgui.sdl.newFrame(self.context());
            drawFn(self._ctx) catch |e| {
                log.err("Got error in `draw`: {}", .{e});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                    kill(self);
                    return;
                }
            };
            imgui.sdl.draw();
            self._renderer.present();
            self.updateFrameStats();
        }

        /// Update frame stats once per second
        inline fn updateFrameStats(self: *@This()) void {
            self._frame_count += 1;
            if ((self._seconds_real - self._last_fps_refresh_time) >= 1.0) {
                const duration = self._seconds_real - self._last_fps_refresh_time;
                self._fps = @as(f32, @floatCast(
                    @as(f64, @floatFromInt(self._frame_count)) / duration,
                ));
                self._last_fps_refresh_time = self._seconds_real;
                const dc_stats = imgui.sdl.getDrawCallStats();
                self._drawcall_count = dc_stats[0] / self._frame_count;
                self._triangle_count = dc_stats[1] / self._frame_count;
                imgui.sdl.clearDrawCallStats();
                self._frame_count = 0;
            }
        }

        /// Check system information
        fn checkSys(_: *const @This()) !void {
            const target = builtin.target;
            var sdl_version: sdl.c.SDL_version = undefined;
            sdl.c.SDL_GetVersion(&sdl_version);
            const ram_size = sdl.c.SDL_GetSystemRAM();

            // Print system info
            log.info(
                \\System info:
                \\    Build Mode    : {s}
                \\    Logging Level : {s}
                \\    Zig Version   : {}
                \\    CPU           : {s}
                \\    ABI           : {s}
                \\    SDL           : {}.{}.{}
                \\    Platform      : {s}
                \\    Memory        : {d}MB
            ,
                .{
                    @tagName(builtin.mode),
                    @tagName(cfg.jok_log_level),
                    builtin.zig_version,
                    @tagName(target.cpu.arch),
                    @tagName(target.abi),
                    sdl_version.major,
                    sdl_version.minor,
                    sdl_version.patch,
                    @tagName(target.os.tag),
                    ram_size,
                },
            );

            if (sdl_version.major < 2 or (sdl_version.minor == 0 and sdl_version.patch < 18)) {
                log.err("Need SDL least version >= 2.0.18", .{});
                return sdl.makeError();
            }

            if (cfg.jok_exit_on_recv_esc) {
                log.info("Press ESC to exit game", .{});
            }
        }

        /// Initialize SDL
        fn initSDL(self: *@This()) !void {
            const sdl_flags = sdl.InitFlags.everything;
            try sdl.init(sdl_flags);

            // Create window
            var window_flags = sdl.WindowFlags{
                .allow_high_dpi = true,
                .mouse_capture = true,
                .mouse_focus = true,
            };
            var window_width: usize = 800;
            var window_height: usize = 600;
            if (cfg.jok_window_borderless) {
                window_flags.borderless = true;
            }
            switch (cfg.jok_window_size) {
                .maximized => {
                    window_flags.dim = .maximized;
                },
                .fullscreen => {
                    self._fullscreen = true;
                    window_flags.dim = .fullscreen;
                },
                .custom => |size| {
                    window_width = @as(usize, size.width);
                    window_height = @as(usize, size.height);
                },
            }
            if (cfg.jok_window_ime_ui) {
                _ = sdl.setHint("SDL_IME_SHOW_UI", "1");
            }
            self._window = try sdl.createWindow(
                cfg.jok_window_title,
                cfg.jok_window_pos_x,
                cfg.jok_window_pos_y,
                window_width,
                window_height,
                window_flags,
            );
            if (cfg.jok_window_min_size) |size| {
                sdl.c.SDL_SetWindowMinimumSize(
                    self._window.ptr,
                    size.width,
                    size.height,
                );
            }
            if (cfg.jok_window_max_size) |size| {
                sdl.c.SDL_SetWindowMaximumSize(
                    self._window.ptr,
                    size.width,
                    size.height,
                );
            }
            toggleResizable(self, cfg.jok_window_resizable);
            toggleAlwaysOnTop(self, cfg.jok_window_always_on_top);

            // Apply mouse mode
            switch (cfg.jok_mouse_mode) {
                .normal => {
                    if (cfg.jok_window_size == .fullscreen) {
                        sdl.c.SDL_SetWindowGrab(self._window.ptr, sdl.c.SDL_FALSE);
                        _ = sdl.c.SDL_ShowCursor(sdl.c.SDL_DISABLE);
                        _ = sdl.c.SDL_SetRelativeMouseMode(sdl.c.SDL_TRUE);
                    } else {
                        _ = sdl.c.SDL_ShowCursor(sdl.c.SDL_ENABLE);
                        _ = sdl.c.SDL_SetRelativeMouseMode(sdl.c.SDL_FALSE);
                    }
                },
                .hide => {
                    if (cfg.jok_window_size == .fullscreen) {
                        sdl.c.SDL_SetWindowGrab(self._window.ptr, sdl.c.SDL_TRUE);
                    }
                    _ = sdl.c.SDL_ShowCursor(sdl.c.SDL_DISABLE);
                    _ = sdl.c.SDL_SetRelativeMouseMode(sdl.c.SDL_TRUE);
                },
            }

            // Create hardware accelerated renderer
            // Fallback to software renderer if allowed
            self._renderer = sdl.createRenderer(
                self._window,
                null,
                .{
                    .software = cfg.jok_software_renderer,
                    .present_vsync = cfg.jok_fps_limit == .auto,
                    .target_texture = true,
                },
            ) catch blk: {
                if (cfg.jok_software_renderer_fallback) {
                    log.warn("Hardware accelerated renderer isn't supported, fallback to software backend", .{});
                    break :blk try sdl.createRenderer(
                        self._window,
                        null,
                        .{
                            .software = true,
                            .present_vsync = cfg.jok_fps_limit == .auto, // Doesn't matter actually, vsync won't work anyway
                            .target_texture = true,
                        },
                    );
                } else {
                    @panic("Failed to create renderer!");
                }
            };
            const rdinfo = try self._renderer.getInfo();
            self._is_software = ((rdinfo.flags & sdl.c.SDL_RENDERER_SOFTWARE) != 0);
            try self._renderer.setDrawBlendMode(.blend);
        }

        /// Deinitialize SDL
        fn deinitSDL(self: *@This()) void {
            self._renderer.destroy();
            self._window.destroy();
            sdl.quit();
        }

        /// Get type-erased context for application
        pub fn context(self: *@This()) Context {
            return .{
                .ctx = self,
                .vtable = .{
                    .allocator = allocator,
                    .running = running,
                    .seconds = seconds,
                    .realSeconds = realSeconds,
                    .deltaSeconds = deltaSeconds,
                    .fps = fps,
                    .window = window,
                    .renderer = renderer,
                    .audioEngine = audioEngine,
                    .kill = kill,
                    .toggleResizable = toggleResizable,
                    .toggleFullscreeen = toggleFullscreeen,
                    .toggleAlwaysOnTop = toggleAlwaysOnTop,
                    .getWindowPosition = getWindowPosition,
                    .getWindowSize = getWindowSize,
                    .getFramebufferSize = getFramebufferSize,
                    .getAspectRatio = getAspectRatio,
                    .getPixelRatio = getPixelRatio,
                    .isKeyPressed = isKeyPressed,
                    .getMouseState = getMouseState,
                    .setMousePosition = setMousePosition,
                    .displayStats = displayStats,
                },
            };
        }

        /////////////////////////////////////////////////////////////////////////////
        ///
        ///  Wrapped API for application context
        ///
        /////////////////////////////////////////////////////////////////////////////

        /// Get meomry allocator
        fn allocator(ptr: *anyopaque) std.mem.Allocator {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._allocator;
        }

        /// Get application running status
        fn running(ptr: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._running;
        }

        /// Get running seconds of application
        fn seconds(ptr: *anyopaque) f32 {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._seconds;
        }

        /// Get running seconds of application (double precision)
        fn realSeconds(ptr: *anyopaque) f64 {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._seconds_real;
        }

        /// Get delta time between frames
        fn deltaSeconds(ptr: *anyopaque) f32 {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._delta_seconds;
        }

        /// Get FPS of application
        fn fps(ptr: *anyopaque) f32 {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._fps;
        }

        /// Get SDL window
        fn window(ptr: *anyopaque) sdl.Window {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._window;
        }

        /// Get SDL renderer
        fn renderer(ptr: *anyopaque) sdl.Renderer {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._renderer;
        }

        /// Get audio engine
        fn audioEngine(ptr: *anyopaque) *zaudio.Engine {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self._audio_engine;
        }

        /// Kill app
        fn kill(ptr: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self._running = false;
        }

        /// Toggle resizable
        fn toggleResizable(ptr: *anyopaque, on_off: ?bool) void {
            var self: *@This() = @ptrCast(@alignCast(ptr));
            if (on_off) |state| {
                self._resizable = state;
            } else {
                self._resizable = !self._resizable;
            }
            _ = sdl.c.SDL_SetWindowResizable(
                self._window.ptr,
                if (self._resizable) sdl.c.SDL_TRUE else sdl.c.SDL_FALSE,
            );
        }

        /// Toggle fullscreen
        fn toggleFullscreeen(ptr: *anyopaque, on_off: ?bool) void {
            var self: *@This() = @ptrCast(@alignCast(ptr));
            if (on_off) |state| {
                self._fullscreen = state;
            } else {
                self._fullscreen = !self._fullscreen;
            }
            _ = sdl.c.SDL_SetWindowFullscreen(
                self._window.ptr,
                if (self._fullscreen) sdl.c.SDL_WINDOW_FULLSCREEN_DESKTOP else 0,
            );
        }

        /// Toggle always-on-top
        fn toggleAlwaysOnTop(ptr: *anyopaque, on_off: ?bool) void {
            var self: *@This() = @ptrCast(@alignCast(ptr));
            if (on_off) |state| {
                self._always_on_top = state;
            } else {
                self._always_on_top = !self._always_on_top;
            }
            _ = sdl.c.SDL_SetWindowAlwaysOnTop(
                self._window.ptr,
                if (self._always_on_top) sdl.c.SDL_TRUE else sdl.c.SDL_FALSE,
            );
        }

        /// Get position of window
        fn getWindowPosition(ptr: *anyopaque) sdl.PointF {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            var x: c_int = undefined;
            var y: c_int = undefined;
            sdl.c.SDL_GetWindowPosition(self._window.ptr, &x, &y);
            return .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
        }

        /// Get size of window
        fn getWindowSize(ptr: *anyopaque) sdl.PointF {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            var w: c_int = undefined;
            var h: c_int = undefined;
            sdl.c.SDL_GetWindowSize(self._window.ptr, &w, &h);
            return .{ .x = @floatFromInt(w), .y = @floatFromInt(h) };
        }

        /// Get size of framebuffer
        fn getFramebufferSize(ptr: *anyopaque) sdl.PointF {
            var self: *@This() = @ptrCast(@alignCast(ptr));
            const fsize = self._renderer.getOutputSize() catch unreachable;
            return .{
                .x = @floatFromInt(fsize.width_pixels),
                .y = @floatFromInt(fsize.height_pixels),
            };
        }

        /// Get aspect ratio of drawing area
        fn getAspectRatio(ptr: *anyopaque) f32 {
            var self: *@This() = @ptrCast(@alignCast(ptr));
            const fsize = self._renderer.getOutputSize() catch unreachable;
            return @as(f32, @floatFromInt(fsize.width_pixels)) / @as(f32, @floatFromInt(fsize.width_pixels));
        }

        /// Get pixel ratio
        fn getPixelRatio(ptr: *anyopaque) f32 {
            const fsize = getFramebufferSize(ptr);
            const wsize = getWindowSize(ptr);
            return fsize.x / wsize.x;
        }

        /// Get key status
        fn isKeyPressed(_: *anyopaque, key: sdl.Scancode) bool {
            const kb_state = sdl.getKeyboardState();
            return kb_state.isPressed(key);
        }

        /// Get mouse state
        fn getMouseState(_: *anyopaque) sdl.MouseState {
            return sdl.getMouseState();
        }

        /// Move mouse to given position (relative to window)
        fn setMousePosition(ptr: *anyopaque, xrel: f32, yrel: f32) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            var w: i32 = undefined;
            var h: i32 = undefined;
            sdl.c.SDL_GetWindowSize(self._window.ptr, &w, &h);
            sdl.c.SDL_WarpMouseInWindow(
                self._window.ptr,
                @intFromFloat(@as(f32, @floatFromInt(w)) * xrel),
                @intFromFloat(@as(f32, @floatFromInt(h)) * yrel),
            );
        }

        /// Display statistics
        fn displayStats(ptr: *anyopaque, opt: DisplayStats) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            const ws = getWindowSize(ptr);
            const fb = getFramebufferSize(ptr);
            imgui.setNextWindowBgAlpha(.{ .alpha = 0.7 });
            imgui.setNextWindowPos(.{ .x = fb.x, .y = 0, .pivot_x = 1 });
            if (imgui.begin("Frame Statistics", .{
                .flags = .{
                    .no_title_bar = !opt.collapsible,
                    .no_move = opt.movable,
                    .no_resize = true,
                    .always_auto_resize = true,
                },
            })) {
                imgui.text("Window Size: {d}x{d}", .{ ws.x, ws.y });
                imgui.text("Framebuffer Size: {d}x{d}", .{ fb.x, fb.y });
                imgui.text("GPU Enabled: {}", .{!self._is_software});
                imgui.text("Optimize Mode: {s}", .{@tagName(builtin.mode)});
                imgui.separator();
                imgui.text("FPS: {d:.1} {s}", .{ self._fps, cfg.jok_fps_limit.str() });
                imgui.text("CPU: {d:.1}ms", .{1000.0 / self._fps});
                imgui.text("Memory: {:.3}", .{std.fmt.fmtIntSizeBin(gpa.total_requested_bytes)});
                imgui.text("Draw Calls: {d}", .{self._drawcall_count});
                imgui.text("Triangles: {d}", .{self._triangle_count});
            }
            imgui.end();
        }
    };
}
