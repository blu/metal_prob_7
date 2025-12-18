#include <metal_stdlib>
using namespace metal;

[[kernel]] void hello(
    device uint8_t *result [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 gdim [[threads_per_grid]])
{
    const uint8_t r = (gid.y & 64) ^ (gid.x & 64);
    result[gid.x + gid.y * gdim.x] = r;
}
