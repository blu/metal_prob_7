#include <metal_stdlib>
using namespace metal;

#if 0
[[kernel]] void hello(
    device uint8_t *result [[buffer(0)]],
    constant uint16_t *frame [[buffer(1)]],
    ushort2 gid [[thread_position_in_grid]],
    ushort2 gdim [[threads_per_grid]])
{
    const uint16_t frame_id = *frame;
    const uint8_t r = (gid.y & (uint16_t)64) ^ ((gid.x + frame_id) & (uint16_t)64);
    result[gid.x + gid.y * gdim.x] = r;
}

[[kernel]] void holla(
    texture2d<half, access::write> result [[texture(0)]],
    constant uint16_t *frame [[buffer(0)]],
    ushort2 gid [[thread_position_in_grid]])
{
    const uint16_t frame_id = *frame;
    const uint8_t r = (gid.y & (uint16_t)64) ^ ((gid.x + frame_id) & (uint16_t)64);
    result.write(r * half(1.0 / 255.0), gid);
}
#else
typedef uint16_t __attribute__ ((ext_vector_type(8))) u16x8;
typedef uint8_t __attribute__ ((ext_vector_type(8))) u8x8;

[[kernel]] void hello(
    device uint8_t *result [[buffer(0)]],
    constant uint32_t *frame [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 gdim [[threads_per_grid]])
{
    const uint32_t frame_id = *frame;
#if 1
    const u8x8 grad = { 32, 64, 96, 128, 128, 96, 64, 32 };
    result[gid.x + gid.y * gdim.x] = grad[(gid.x + frame_id) / 64 % 8];
#else
    result[gid.x + gid.y * gdim.x] = (gid.x + frame_id) / 64 % 8;
#endif
}

[[kernel]] void holla(
    texture2d<half, access::write> result [[texture(0)]],
    constant uint32_t *frame [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    const uint32_t frame_id = *frame;
    const uint8_t r = (gid.y & 64) ^ ((gid.x + frame_id) & 64);
    result.write(r * half(1.0 / 255.0), gid);
}
#endif

