const jok = @import("jok.zig");
const sdl = jok.sdl;

pub const BlendMethod = enum {
    // no blending
    // dstRGBA = srcRGBA
    none,

    // alpha blending
    // dstRGB = (srcRGB * srcA) + (dstRGB * (1-srcA))
    // dstA = srcA + (dstA * (1-srcA))
    blend,

    // additive blending
    // dstRGB = (srcRGB * srcA) + dstRGB
    // dstA = dstA
    additive,

    // color modulate
    // dstRGB = srcRGB * dstRGB
    // dstA = dstA
    modulate,

    // color multiply
    // dstRGB = (srcRGB * dstRGB) + (dstRGB * (1-srcA))
    // dstA = dstA
    multiply,

    //------------------------------------------------------------------------------
    // Porter Duff compositing, might not supported on certain platform
    // https://ssp.impulsetrain.com/porterduff.html
    //------------------------------------------------------------------------------
    pd_src,
    pd_src_atop,
    pd_src_over,
    pd_src_in,
    pd_src_out,
    pd_dst,
    pd_dst_atop,
    pd_dst_over,
    pd_dst_in,
    pd_dst_out,
    pd_xor,
    pd_lighter,
    pd_clear,

    pub fn toMode(self: @This()) c_uint {
        return switch (self) {
            .none => sdl.c.SDL_BLENDMODE_NONE,
            .blend => sdl.c.SDL_BLENDMODE_BLEND,
            .additive => sdl.c.SDL_BLENDMODE_ADD,
            .modulate => sdl.c.SDL_BLENDMODE_MOD,
            .multiply => sdl.c.SDL_BLENDMODE_MUL,
            .pd_src => _pd_src,
            .pd_src_atop => _pd_src_atop,
            .pd_src_over => _pd_src_over,
            .pd_src_in => _pd_src_in,
            .pd_src_out => _pd_src_out,
            .pd_dst => _pd_dst,
            .pd_dst_atop => _pd_dst_atop,
            .pd_dst_over => _pd_dst_over,
            .pd_dst_in => _pd_dst_in,
            .pd_dst_out => _pd_dst_out,
            .pd_xor => _pd_xor,
            .pd_lighter => _pd_lighter,
            .pd_clear => _pd_clear,
        };
    }
};

var _pd_src: c_uint = undefined;
var _pd_src_atop: c_uint = undefined;
var _pd_src_over: c_uint = undefined;
var _pd_src_in: c_uint = undefined;
var _pd_src_out: c_uint = undefined;
var _pd_dst: c_uint = undefined;
var _pd_dst_atop: c_uint = undefined;
var _pd_dst_over: c_uint = undefined;
var _pd_dst_in: c_uint = undefined;
var _pd_dst_out: c_uint = undefined;
var _pd_xor: c_uint = undefined;
var _pd_lighter: c_uint = undefined;
var _pd_clear: c_uint = undefined;

// Initialize custom blending methods
pub fn init() void {
    _pd_src = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_src_atop = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_src_over = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_src_in = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_src_out = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_dst = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_dst_atop = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_dst_over = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_dst_in = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDFACTOR_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDFACTOR_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_dst_out = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_xor = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
        sdl.c.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_lighter = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDFACTOR_ONE,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
    _pd_clear = sdl.c.SDL_ComposeCustomBlendMode(
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDOPERATION_ADD,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDFACTOR_ZERO,
        sdl.c.SDL_BLENDOPERATION_ADD,
    );
}
