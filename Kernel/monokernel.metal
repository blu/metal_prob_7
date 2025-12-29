#include <metal_stdlib>
using namespace metal;

// OCL compat types; avoid clash with scalarN types, which exist as reserved
// names but are not usable; see "__Reserved_Name__Do_not_use_" types
typedef uint16_t __attribute__((ext_vector_type(8))) u16x8;
typedef int16_t  __attribute__((ext_vector_type(8))) s16x8;
typedef uint32_t __attribute__((ext_vector_type(8))) u32x8;
typedef int32_t  __attribute__((ext_vector_type(8))) s32x8;
typedef float    __attribute__((ext_vector_type(8))) f32x8;

// bool vectors; we never declare vars of these types, but
// they may appear as temporaries, which we may then convert
// to int-based masks
typedef bool __attribute__((ext_vector_type(3))) b3;
typedef bool __attribute__((ext_vector_type(4))) b4;
typedef bool __attribute__((ext_vector_type(8))) b8;

int3 convert_int3(b3 a)
{
    return -int3(
        int(a[0]),
        int(a[1]),
        int(a[2]));
}

int4 convert_int4(b4 a)
{
    return -int4(
        int(a[0]),
        int(a[1]),
        int(a[2]),
        int(a[3]));
}

s32x8 convert_int8(b8 a)
{
    return -s32x8(
        int(a[0]),
        int(a[1]),
        int(a[2]),
        int(a[3]),
        int(a[4]),
        int(a[5]),
        int(a[6]),
        int(a[7]));
}

u32x8 convert_uint8(u16x8 a)
{
    return u32x8(
        int(a[0]),
        int(a[1]),
        int(a[2]),
        int(a[3]),
        int(a[4]),
        int(a[5]),
        int(a[6]),
        int(a[7]));
}

uint32_t as_uint(float a)
{
    return reinterpret_cast< thread uint32_t& >(a);
}

int3 as_int3(float3 a)
{
    return reinterpret_cast< thread int3& >(a);
}

float as_float(uint a)
{
    return reinterpret_cast< thread float& >(a);
}

float3 as_float3(int3 a)
{
    return reinterpret_cast< thread float3& >(a);
}

int isless(float a, float b)
{
    return a < b;
}

s32x8 isless(f32x8 a, f32x8 b)
{
    return convert_int8(a < b);
}

int3 islessequal(float3 a, float3 b)
{
    return convert_int3(a <= b);
}

int4 islessequal(float4 a, float4 b)
{
    return convert_int4(a <= b);
}

int isgreaterequal(float a, float b)
{
    return a >= b;
}

int4 select(int4 a, int4 b, int4 c)
{
    return int4(
        c[0] ? b[0] : a[0],
        c[1] ? b[1] : a[1],
        c[2] ? b[2] : a[2],
        c[3] ? b[3] : a[3]);
}

float3 select(float3 a, float3 b, uint3 c)
{
    return float3(
        c[0] ? b[0] : a[0],
        c[1] ? b[1] : a[1],
        c[2] ? b[2] : a[2]);
}

f32x8 select(f32x8 a, f32x8 b, s32x8 c)
{
    return f32x8(
        c[0] ? b[0] : a[0],
        c[1] ? b[1] : a[1],
        c[2] ? b[2] : a[2],
        c[3] ? b[3] : a[3],
        c[4] ? b[4] : a[4],
        c[5] ? b[5] : a[5],
        c[6] ? b[6] : a[6],
        c[7] ? b[7] : a[7]);
}

f32x8 fmin(f32x8 a, f32x8 b)
{
    const float4 a_lo = float4(a[0], a[1], a[2], a[3]);
    const float4 a_hi = float4(a[4], a[5], a[6], a[7]);
    const float4 b_lo = float4(b[0], b[1], b[2], b[3]);
    const float4 b_hi = float4(b[4], b[5], b[6], b[7]);

    return f32x8(fmin(a_lo, b_lo), fmin(a_hi, b_hi));
}

f32x8 fmax(f32x8 a, f32x8 b)
{
    const float4 a_lo = float4(a[0], a[1], a[2], a[3]);
    const float4 a_hi = float4(a[4], a[5], a[6], a[7]);
    const float4 b_lo = float4(b[0], b[1], b[2], b[3]);
    const float4 b_hi = float4(b[4], b[5], b[6], b[7]);

    return f32x8(fmax(a_lo, b_lo), fmax(a_hi, b_hi));
}

#define M_PI 3.1415926535897932f

// source_prologue
struct BBox {
	float3 min;
	float3 max;
};

struct Ray {
	float4 origin; // .xyz = origin, .w = as_float(prior_id)
	float4 rcpdir; // .xyz = rcpdir, .w = dist
};

struct Hit {
	int3 min_mask;
	int a_mask;
	int b_mask;
};

struct RayHit {
	struct Ray ray;
	struct Hit hit;
};

struct Octet {
	u16x8 child;
};

struct Leaf {
	u16x8 start;
 	u16x8 count;
};

struct Voxel {
	float4 min;
	float4 max;
};

struct ChildIndex {
	f32x8 distance;
	u32x8 index;
};

inline float intersect(
	thread const struct BBox* const bbox,
	thread const struct Ray* const ray,
	thread struct Hit* const hit)
{
	const float3 t0 = (bbox->min - ray->origin.xyz) * ray->rcpdir.xyz;
	const float3 t1 = (bbox->max - ray->origin.xyz) * ray->rcpdir.xyz;
	const float ray_len = ray->rcpdir.w;

	const float3 axial_min = fmin(t0, t1);
	const float3 axial_max = fmax(t0, t1);

	hit->min_mask = islessequal(t0, t1);
	hit->a_mask = isgreaterequal(axial_min.x, axial_min.y);
	hit->b_mask = isgreaterequal(fmax(axial_min.x, axial_min.y), axial_min.z);

	const float min = fmax(fmax(axial_min.x, axial_min.y), axial_min.z);
	const float max = fmin(fmin(axial_max.x, axial_max.y), axial_max.z);

#if INFINITE_RAY
	return select(INFINITY, min, isless(0.f, min) & isless(min, max));
#else
	return select(INFINITY, min, isless(0.f, min) & isless(min, max) & isless(min, ray_len));
#endif
}

inline bool occluded(
	thread const struct BBox* const bbox,
	thread const struct Ray* const ray)
{
	const float3 t0 = (bbox->min - ray->origin.xyz) * ray->rcpdir.xyz;
	const float3 t1 = (bbox->max - ray->origin.xyz) * ray->rcpdir.xyz;
	const float ray_len = ray->rcpdir.w;

	const float3 axial_min = fmin(t0, t1);
	const float3 axial_max = fmax(t0, t1);

	const float min = fmax(fmax(axial_min.x, axial_min.y), axial_min.z);
	const float max = fmin(fmin(axial_max.x, axial_max.y), axial_max.z);

#if INFINITE_RAY
	return isless(0.f, min) & isless(min, max);
#else
	return isless(0.f, min) & isless(min, max) & isless(min, ray_len);
#endif
}

inline void intersect8(
	const f32x8 bbox_min_x,
	const f32x8 bbox_min_y,
	const f32x8 bbox_min_z,
	const f32x8 bbox_max_x,
	const f32x8 bbox_max_y,
	const f32x8 bbox_max_z,
	thread const struct Ray* const ray,
	thread f32x8* const t,
	thread s32x8* const r)
{
	const float3 ray_origin = ray->origin.xyz;
	const float3 ray_rcpdir = ray->rcpdir.xyz;
	const float ray_len = ray->rcpdir.w;

	const f32x8 tmin_x = (bbox_min_x - ray_origin.xxxxxxxx) * ray_rcpdir.xxxxxxxx;
	const f32x8 tmax_x = (bbox_max_x - ray_origin.xxxxxxxx) * ray_rcpdir.xxxxxxxx;
	const f32x8 tmin_y = (bbox_min_y - ray_origin.yyyyyyyy) * ray_rcpdir.yyyyyyyy;
	const f32x8 tmax_y = (bbox_max_y - ray_origin.yyyyyyyy) * ray_rcpdir.yyyyyyyy;
	const f32x8 tmin_z = (bbox_min_z - ray_origin.zzzzzzzz) * ray_rcpdir.zzzzzzzz;
	const f32x8 tmax_z = (bbox_max_z - ray_origin.zzzzzzzz) * ray_rcpdir.zzzzzzzz;

	const f32x8 x_min = fmin(tmin_x, tmax_x);
	const f32x8 x_max = fmax(tmin_x, tmax_x);
	const f32x8 y_min = fmin(tmin_y, tmax_y);
	const f32x8 y_max = fmax(tmin_y, tmax_y);
	const f32x8 z_min = fmin(tmin_z, tmax_z);
	const f32x8 z_max = fmax(tmin_z, tmax_z);

	const f32x8 min = fmax(fmax(x_min, y_min), z_min);
	const f32x8 max = fmin(fmin(x_max, y_max), z_max);
	*t = max;

#if INFINITE_RAY
	const s32x8 msk = isless(min, max) & isless(f32x8(0.f), max);
#else
	const s32x8 msk = isless(min, max) & isless(f32x8(0.f), max) & isless(min, f32x8(ray_len));
#endif
	*r = msk;
}

uint octlf_intersect_wide(
	thread const struct Leaf octet,
	thread const struct BBox* const bbox,
	thread const struct Ray* const ray,
	thread struct ChildIndex* const child_index)
{
	const float3 par_min = bbox->min;
	const float3 par_max = bbox->max;
	const float3 par_mid = (par_min + par_max) * 0.5f;

	const f32x8 bbox_min_x = f32x8( par_min.x, par_mid.x, par_min.x, par_mid.x, par_min.x, par_mid.x, par_min.x, par_mid.x );
	const f32x8 bbox_min_y = f32x8( par_min.yy, par_mid.yy, par_min.yy, par_mid.yy );
	const f32x8 bbox_min_z = f32x8( par_min.zzzz, par_mid.zzzz );
	const f32x8 bbox_max_x = f32x8( par_mid.x, par_max.x, par_mid.x, par_max.x, par_mid.x, par_max.x, par_mid.x, par_max.x );
	const f32x8 bbox_max_y = f32x8( par_mid.yy, par_max.yy, par_mid.yy, par_max.yy );
	const f32x8 bbox_max_z = f32x8( par_mid.zzzz, par_max.zzzz );

	f32x8 t;
	s32x8 r;
	intersect8(bbox_min_x, bbox_min_y, bbox_min_z, bbox_max_x, bbox_max_y, bbox_max_z, ray, &t, &r);
	const s32x8 occupancy = convert_int8(u16x8(0) != octet.count);
	r &= occupancy;

#if OCL_QUIRK_0004
	const s32x8 cnt0 = -r;
	const int4 cnt1 = int4(cnt0[0], cnt0[1], cnt0[2], cnt0[3]) + int4(cnt0[4], cnt0[5], cnt0[6], cnt0[7]);
	const int2 cnt2 = int2(cnt1[0], cnt1[1]) + int2(cnt1[2], cnt1[3]);
	const int count = cnt2[0] + cnt2[1];

#else
	int count = 0;
	count -= r[0];
	count -= r[1];
	count -= r[2];
	count -= r[3];
	count -= r[4];
	count -= r[5];
	count -= r[6];
	count -= r[7];

#endif
	t = select(f32x8(INFINITY), t, r);

	const float4 r0_A = float4(t[0], t[3], t[4], t[7]);
	const float4 r0_B = float4(t[1], t[2], t[5], t[6]);
	const int4 r0x_A = int4(0, 3, 4, 7);
	const int4 r0x_B = int4(1, 2, 5, 6);
	const int4 m0 = islessequal(r0_A, r0_B);
	const float4 r0_min = fmin(r0_A, r0_B);
	const float4 r0_max = fmax(r0_A, r0_B);
	const int4 r0x_min = select(r0x_B, r0x_A, m0);
	const int4 r0x_max = select(r0x_A, r0x_B, m0);

	const float4 r1_A = float4(r0_min[0], r0_max[0], r0_max[3], r0_min[3]);
	const float4 r1_B = float4(r0_max[1], r0_min[1], r0_min[2], r0_max[2]);
	const int4 r1x_A = int4(r0x_min[0], r0x_max[0], r0x_max[3], r0x_min[3]);
	const int4 r1x_B = int4(r0x_max[1], r0x_min[1], r0x_min[2], r0x_max[2]);
	const int4 m1 = islessequal(r1_A, r1_B);
	const float4 r1_min = fmin(r1_A, r1_B);
	const float4 r1_max = fmax(r1_A, r1_B);
	const int4 r1x_min = select(r1x_B, r1x_A, m1);
	const int4 r1x_max = select(r1x_A, r1x_B, m1);

	const float4 r2_A = float4(r1_min[0], r1_max[0], r1_max[3], r1_min[3]);
	const float4 r2_B = float4(r1_min[1], r1_max[1], r1_max[2], r1_min[2]);
	const int4 r2x_A = int4(r1x_min[0], r1x_max[0], r1x_max[3], r1x_min[3]);
	const int4 r2x_B = int4(r1x_min[1], r1x_max[1], r1x_max[2], r1x_min[2]);
	const int4 m2 = islessequal(r2_A, r2_B);
	const float4 r2_min = fmin(r2_A, r2_B);
	const float4 r2_max = fmax(r2_A, r2_B);
	const int4 r2x_min = select(r2x_B, r2x_A, m2);
	const int4 r2x_max = select(r2x_A, r2x_B, m2);

	const float4 r3_A = float4(r2_min[0], r2_max[0], r2_min[1], r2_max[1]);
	const float4 r3_B = float4(r2_max[2], r2_min[2], r2_max[3], r2_min[3]);
	const int4 r3x_A = int4(r2x_min[0], r2x_max[0], r2x_min[1], r2x_max[1]);
	const int4 r3x_B = int4(r2x_max[2], r2x_min[2], r2x_max[3], r2x_min[3]);
	const int4 m3 = islessequal(r3_A, r3_B);
	const float4 r3_min = fmin(r3_A, r3_B);
	const float4 r3_max = fmax(r3_A, r3_B);
	const int4 r3x_min = select(r3x_B, r3x_A, m3);
	const int4 r3x_max = select(r3x_A, r3x_B, m3);

	const float4 r4_A = float4(r3_min[0], r3_min[1], r3_max[0], r3_max[1]);
	const float4 r4_B = float4(r3_min[2], r3_min[3], r3_max[2], r3_max[3]);
	const int4 r4x_A = int4(r3x_min[0], r3x_min[1], r3x_max[0], r3x_max[1]);
	const int4 r4x_B = int4(r3x_min[2], r3x_min[3], r3x_max[2], r3x_max[3]);
	const int4 m4 = islessequal(r4_A, r4_B);
	const float4 r4_min = fmin(r4_A, r4_B);
	const float4 r4_max = fmax(r4_A, r4_B);
	const int4 r4x_min = select(r4x_B, r4x_A, m4);
	const int4 r4x_max = select(r4x_A, r4x_B, m4);

	const float4 r5_A = float4(r4_min[0], r4_max[0], r4_min[2], r4_max[2]);
	const float4 r5_B = float4(r4_min[1], r4_max[1], r4_min[3], r4_max[3]);
	const int4 r5x_A = int4(r4x_min[0], r4x_max[0], r4x_min[2], r4x_max[2]);
	const int4 r5x_B = int4(r4x_min[1], r4x_max[1], r4x_min[3], r4x_max[3]);
	const int4 m5 = islessequal(r5_A, r5_B);
	const float4 r5_min = fmin(r5_A, r5_B);
	const float4 r5_max = fmax(r5_A, r5_B);
	const int4 r5x_min = select(r5x_B, r5x_A, m5);
	const int4 r5x_max = select(r5x_A, r5x_B, m5);

	child_index->distance = f32x8(r5_min[0], r5_max[0], r5_min[1], r5_max[1], r5_min[2], r5_max[2], r5_min[3], r5_max[3]);
	child_index->index = u32x8(r5x_min[0], r5x_max[0], r5x_min[1], r5x_max[1], r5x_min[2], r5x_max[2], r5x_min[3], r5x_max[3]);
	return uint(count);
}

uint octet_intersect_wide(
	const struct Octet octet,
	thread const struct BBox* const bbox,
	thread const struct Ray* const ray,
	thread struct ChildIndex* const child_index,
	struct BBox child_bbox[8])
{
	const float3 par_min = bbox->min;
	const float3 par_max = bbox->max;
	const float3 par_mid = (par_min + par_max) * 0.5f;

	const f32x8 bbox_min_x = f32x8( par_min.x, par_mid.x, par_min.x, par_mid.x, par_min.x, par_mid.x, par_min.x, par_mid.x );
	const f32x8 bbox_min_y = f32x8( par_min.yy, par_mid.yy, par_min.yy, par_mid.yy );
	const f32x8 bbox_min_z = f32x8( par_min.zzzz, par_mid.zzzz );
	const f32x8 bbox_max_x = f32x8( par_mid.x, par_max.x, par_mid.x, par_max.x, par_mid.x, par_max.x, par_mid.x, par_max.x );
	const f32x8 bbox_max_y = f32x8( par_mid.yy, par_max.yy, par_mid.yy, par_max.yy );
	const f32x8 bbox_max_z = f32x8( par_mid.zzzz, par_max.zzzz );

	child_bbox[0] = (struct BBox){ float3( bbox_min_x[0], bbox_min_y[0], bbox_min_z[0] ), float3( bbox_max_x[0], bbox_max_y[0], bbox_max_z[0] ) };
	child_bbox[1] = (struct BBox){ float3( bbox_min_x[1], bbox_min_y[1], bbox_min_z[1] ), float3( bbox_max_x[1], bbox_max_y[1], bbox_max_z[1] ) };
	child_bbox[2] = (struct BBox){ float3( bbox_min_x[2], bbox_min_y[2], bbox_min_z[2] ), float3( bbox_max_x[2], bbox_max_y[2], bbox_max_z[2] ) };
	child_bbox[3] = (struct BBox){ float3( bbox_min_x[3], bbox_min_y[3], bbox_min_z[3] ), float3( bbox_max_x[3], bbox_max_y[3], bbox_max_z[3] ) };
	child_bbox[4] = (struct BBox){ float3( bbox_min_x[4], bbox_min_y[4], bbox_min_z[4] ), float3( bbox_max_x[4], bbox_max_y[4], bbox_max_z[4] ) };
	child_bbox[5] = (struct BBox){ float3( bbox_min_x[5], bbox_min_y[5], bbox_min_z[5] ), float3( bbox_max_x[5], bbox_max_y[5], bbox_max_z[5] ) };
	child_bbox[6] = (struct BBox){ float3( bbox_min_x[6], bbox_min_y[6], bbox_min_z[6] ), float3( bbox_max_x[6], bbox_max_y[6], bbox_max_z[6] ) };
	child_bbox[7] = (struct BBox){ float3( bbox_min_x[7], bbox_min_y[7], bbox_min_z[7] ), float3( bbox_max_x[7], bbox_max_y[7], bbox_max_z[7] ) };

	f32x8 t;
	s32x8 r;
	intersect8(bbox_min_x, bbox_min_y, bbox_min_z, bbox_max_x, bbox_max_y, bbox_max_z, ray, &t, &r);
	const s32x8 occupancy = convert_int8(u16x8(-1) != octet.child);
	r &= occupancy;

#if OCL_QUIRK_0004
    const s32x8 cnt0 = -r;
    const int4 cnt1 = int4(cnt0[0], cnt0[1], cnt0[2], cnt0[3]) + int4(cnt0[4], cnt0[5], cnt0[6], cnt0[7]);
    const int2 cnt2 = int2(cnt1[0], cnt1[1]) + int2(cnt1[2], cnt1[3]);
    const int count = cnt2[0] + cnt2[1];

#else
	int count = 0;
	count -= r[0];
	count -= r[1];
	count -= r[2];
	count -= r[3];
	count -= r[4];
	count -= r[5];
	count -= r[6];
	count -= r[7];

#endif
	t = select(f32x8(INFINITY), t, r);

	const float4 r0_A = float4(t[0], t[3], t[4], t[7]);
	const float4 r0_B = float4(t[1], t[2], t[5], t[6]);
	const int4 r0x_A = int4(0, 3, 4, 7);
	const int4 r0x_B = int4(1, 2, 5, 6);
	const int4 m0 = islessequal(r0_A, r0_B);
	const float4 r0_min = fmin(r0_A, r0_B);
	const float4 r0_max = fmax(r0_A, r0_B);
	const int4 r0x_min = select(r0x_B, r0x_A, m0);
	const int4 r0x_max = select(r0x_A, r0x_B, m0);

	const float4 r1_A = float4(r0_min[0], r0_max[0], r0_max[3], r0_min[3]);
	const float4 r1_B = float4(r0_max[1], r0_min[1], r0_min[2], r0_max[2]);
	const int4 r1x_A = int4(r0x_min[0], r0x_max[0], r0x_max[3], r0x_min[3]);
	const int4 r1x_B = int4(r0x_max[1], r0x_min[1], r0x_min[2], r0x_max[2]);
	const int4 m1 = islessequal(r1_A, r1_B);
	const float4 r1_min = fmin(r1_A, r1_B);
	const float4 r1_max = fmax(r1_A, r1_B);
	const int4 r1x_min = select(r1x_B, r1x_A, m1);
	const int4 r1x_max = select(r1x_A, r1x_B, m1);

	const float4 r2_A = float4(r1_min[0], r1_max[0], r1_max[3], r1_min[3]);
	const float4 r2_B = float4(r1_min[1], r1_max[1], r1_max[2], r1_min[2]);
	const int4 r2x_A = int4(r1x_min[0], r1x_max[0], r1x_max[3], r1x_min[3]);
	const int4 r2x_B = int4(r1x_min[1], r1x_max[1], r1x_max[2], r1x_min[2]);
	const int4 m2 = islessequal(r2_A, r2_B);
	const float4 r2_min = fmin(r2_A, r2_B);
	const float4 r2_max = fmax(r2_A, r2_B);
	const int4 r2x_min = select(r2x_B, r2x_A, m2);
	const int4 r2x_max = select(r2x_A, r2x_B, m2);

	const float4 r3_A = float4(r2_min[0], r2_max[0], r2_min[1], r2_max[1]);
	const float4 r3_B = float4(r2_max[2], r2_min[2], r2_max[3], r2_min[3]);
	const int4 r3x_A = int4(r2x_min[0], r2x_max[0], r2x_min[1], r2x_max[1]);
	const int4 r3x_B = int4(r2x_max[2], r2x_min[2], r2x_max[3], r2x_min[3]);
	const int4 m3 = islessequal(r3_A, r3_B);
	const float4 r3_min = fmin(r3_A, r3_B);
	const float4 r3_max = fmax(r3_A, r3_B);
	const int4 r3x_min = select(r3x_B, r3x_A, m3);
	const int4 r3x_max = select(r3x_A, r3x_B, m3);

	const float4 r4_A = float4(r3_min[0], r3_min[1], r3_max[0], r3_max[1]);
	const float4 r4_B = float4(r3_min[2], r3_min[3], r3_max[2], r3_max[3]);
	const int4 r4x_A = int4(r3x_min[0], r3x_min[1], r3x_max[0], r3x_max[1]);
	const int4 r4x_B = int4(r3x_min[2], r3x_min[3], r3x_max[2], r3x_max[3]);
	const int4 m4 = islessequal(r4_A, r4_B);
	const float4 r4_min = fmin(r4_A, r4_B);
	const float4 r4_max = fmax(r4_A, r4_B);
	const int4 r4x_min = select(r4x_B, r4x_A, m4);
	const int4 r4x_max = select(r4x_A, r4x_B, m4);

	const float4 r5_A = float4(r4_min[0], r4_max[0], r4_min[2], r4_max[2]);
	const float4 r5_B = float4(r4_min[1], r4_max[1], r4_min[3], r4_max[3]);
	const int4 r5x_A = int4(r4x_min[0], r4x_max[0], r4x_min[2], r4x_max[2]);
	const int4 r5x_B = int4(r4x_min[1], r4x_max[1], r4x_min[3], r4x_max[3]);
	const int4 m5 = islessequal(r5_A, r5_B);
	const float4 r5_min = fmin(r5_A, r5_B);
	const float4 r5_max = fmax(r5_A, r5_B);
	const int4 r5x_min = select(r5x_B, r5x_A, m5);
	const int4 r5x_max = select(r5x_A, r5x_B, m5);

	child_index->distance = f32x8(r5_min[0], r5_max[0], r5_min[1], r5_max[1], r5_min[2], r5_max[2], r5_min[3], r5_max[3]);
	child_index->index = u32x8(r5x_min[0], r5x_max[0], r5x_min[1], r5x_max[1], r5x_min[2], r5x_max[2], r5x_min[3], r5x_max[3]);
	return uint(count);
}

// see George Marsaglia http://www.jstatsoft.org/v08/i14/paper
unsigned xorshift(unsigned value) {
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value;
}

// source_buffer
inline struct Octet get_octet(
	device const ushort4* const octet,
	const uint idx)
{
	return (struct Octet){
		u16x8(
			octet[idx * 2 + 0],
			octet[idx * 2 + 1]
		)
	};
}
inline struct Leaf get_leaf(
	device const ushort4* const leaf,
	const uint idx)
{
	return (struct Leaf){
		u16x8(
			leaf[idx * 4 + 0],
			leaf[idx * 4 + 1]
		),
		u16x8(
			leaf[idx * 4 + 2],
			leaf[idx * 4 + 3]
		)
	};
}
inline struct Voxel get_voxel(
	device const float4* const voxel,
	const uint idx)
{
	return (struct Voxel){
		voxel[idx * 2 + 0],
		voxel[idx * 2 + 1]
	};
}

uint traverself(
	const struct Leaf leaf,
	device const float4* const voxel,
	thread const struct BBox* const bbox,
	thread struct Ray* const ray,
	thread struct Hit* const hit)
{
	struct ChildIndex child_index;

	const uint hit_count = octlf_intersect_wide(
		leaf,
		bbox,
		ray,
		&child_index);

	const f32x8 distance = child_index.distance;
	const u32x8 index = child_index.index;
	const u32x8 leaf_start = convert_uint8(leaf.start);
	const u32x8 leaf_count = convert_uint8(leaf.count);
	const uint prior_id = as_uint(ray->origin.w);

	for (uint i = 0; i < hit_count; ++i) {
		const uint payload_start = leaf_start[index[i]];
		const uint payload_count = leaf_count[index[i]];
		float nearest_dist = distance[i];

		uint voxel_id = -1U;
		struct Hit maybe_hit;

		for (uint j = payload_start; j < payload_start + payload_count; ++j) {
			const struct Voxel payload = get_voxel(voxel, j);
			const struct BBox payload_bbox = { payload.min.xyz, payload.max.xyz };
			const uint id = as_uint(payload.min.w);
			const float dist = intersect(&payload_bbox, ray, &maybe_hit);

			if (id != prior_id & dist < nearest_dist) {
				nearest_dist = dist;
				voxel_id = id;
				*hit = maybe_hit;
			}
		}

		if (-1U != voxel_id) {
			ray->rcpdir.w = nearest_dist;
			return voxel_id;
		}
	}
	return -1U;
}

bool occludelf(
	const struct Leaf leaf,
	device const float4* const voxel,
	thread const struct BBox* const bbox,
	thread const struct Ray* const ray)
{
	struct ChildIndex child_index;

	const uint hit_count = octlf_intersect_wide(
		leaf,
		bbox,
		ray,
		&child_index);

	const u32x8 index = child_index.index;
	const u32x8 leaf_start = convert_uint8(leaf.start);
	const u32x8 leaf_count = convert_uint8(leaf.count);
	const uint prior_id = as_uint(ray->origin.w);

	for (uint i = 0; i < hit_count; ++i) {
		const uint payload_start = leaf_start[index[i]];
		const uint payload_count = leaf_count[index[i]];

		for (uint j = payload_start; j < payload_start + payload_count; ++j) {
			const struct Voxel payload = get_voxel(voxel, j);
			const struct BBox payload_bbox = { payload.min.xyz, payload.max.xyz };
			const uint id = as_uint(payload.min.w);

			if (id != prior_id & occluded(&payload_bbox, ray))
				return true;
		}
	}
	return false;
}

uint traverse(
	const struct Octet octet,
	device const ushort4* const leaf,
	device const float4* const voxel,
	thread const struct BBox* const bbox,
	thread struct Ray* const ray,
	thread struct Hit* const hit)
{
	struct ChildIndex child_index;
	struct BBox child_bbox[8];

	const uint hit_count = octet_intersect_wide(
		octet,
		bbox,
		ray,
		&child_index,
		child_bbox);

	const u32x8 index = child_index.index;
	const u32x8 octet_child = convert_uint8(octet.child);

	for (uint i = 0; i < hit_count; ++i) {
		const uint child = octet_child[index[i]];
		const uint hitId = traverself(get_leaf(leaf, child), voxel, child_bbox + index[i], ray, hit);

		if (-1U != hitId)
			return hitId;
	}
	return -1U;
}

bool occlude(
	const struct Octet octet,
	device const ushort4* const leaf,
	device const float4* const voxel,
	thread const struct BBox* const bbox,
	thread const struct Ray* const ray)
{
	struct ChildIndex child_index;
	struct BBox child_bbox[8];

	const uint hit_count = octet_intersect_wide(
		octet,
		bbox,
		ray,
		&child_index,
		child_bbox);

	const u32x8 index = child_index.index;
	const u32x8 octet_child = convert_uint8(octet.child);

	for (uint i = 0; i < hit_count; ++i) {
		const uint child = octet_child[index[i]];

		if (occludelf(get_leaf(leaf, child), voxel, child_bbox + index[i], ray))
			return true;
	}
	return false;
}

[[ kernel ]]
void monokernel(
	device const ushort4* const src_a [[buffer(0)]],
	device const ushort4* const src_b [[buffer(1)]],
	device const float4* const src_c [[buffer(2)]],
#if OCL_QUIRK_0001
	constant float* const src_d [[buffer(3)]],
#else
	constant float4* const src_d [[buffer(3)]],
#endif
    texture2d< half, access::write > dst [[texture(0)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 gdim [[threads_per_grid]])
{
// source_main
	const int idx = int(gid.x);
	const int idy = int(gid.y);
	const int dimx = int(gdim.x);
	const int dimy = int(gdim.y);
#if OCL_QUIRK_0001
	const float3 cam0 = float3(src_d[0], src_d[1], src_d[ 2]);
	const float3 cam1 = float3(src_d[4], src_d[5], src_d[ 6]);
	const float3 cam2 = float3(src_d[8], src_d[9], src_d[10]);
	const float3 ray_origin = float3(src_d[12], src_d[13], src_d[14]);
	const float3 bbox_min   = float3(src_d[16], src_d[17], src_d[18]);
	const float3 bbox_max   = float3(src_d[20], src_d[21], src_d[22]);
    const uint frame        = as_uint(src_d[23]);
#else
	const float3 cam0 = src_d[0].xyz;
	const float3 cam1 = src_d[1].xyz;
	const float3 cam2 = src_d[2].xyz;
	const float3 ray_origin = src_d[3].xyz;
	const float3 bbox_min   = src_d[4].xyz;
	const float3 bbox_max   = src_d[5].xyz;
    const uint frame        = as_uint(src_d[5].w);
#endif
	const struct BBox root_bbox = { bbox_min, bbox_max };
	const float3 ray_direction =
		cam0 * ((idx * 2 - dimx) * (1.0f / dimx)) +
		cam1 * ((idy * 2 - dimy) * (1.0f / dimy)) +
		cam2;
	const float3 ray_rcpdir = clamp(1.f / ray_direction, -MAXFLOAT, MAXFLOAT);
	struct RayHit ray = { { float4(ray_origin, as_float(-1U)), float4(ray_rcpdir, MAXFLOAT) } };
	uint result = traverse(get_octet(src_a, 0), src_b, src_c, &root_bbox, &ray.ray, &ray.hit);

	if (-1U != result) {
		const unsigned seed = idx + idy * dimx + frame * dimy * dimx;
#if 0
		const unsigned ri0 = xorshift(seed) * 0x5557 >> 8;
		const unsigned ri1 = xorshift(seed) * 0x7175 >> 8;
#else
		const unsigned ri0 = xorshift(seed) * 0xa47f >> 8;
		const unsigned ri1 = xorshift(seed) * 0xa175 >> 8;
#endif
		const unsigned max_rand = (1U << 24) - 1;

		// cosine-weighted distribution
		const float r0 = ri0 * (1.f / max_rand); // decl (cos^2)
		const float r1 = ri1 * (M_PI / (1U << 23)); // azim
		const float sin_decl = sqrt(1.f - r0);
		const float cos_decl = sqrt(r0);
		float sin_azim;
		float cos_azim;
		sin_azim = sincos(r1, cos_azim);

		// compute a bounce vector in some TBN space, in this case of an assumed normal along x-axis
		const float3 hemi = float3(cos_decl, cos_azim * sin_decl, sin_azim * sin_decl);

#if OCL_QUIRK_0002
		const uint a_mask = ray.hit.a_mask;
		const uint b_mask = ray.hit.b_mask;
		const float3 normal = b_mask ? (a_mask ? hemi.xyz : hemi.zxy) : hemi.yzx;
#else
		const uint a_mask = -ray.hit.a_mask;
		const uint b_mask = -ray.hit.b_mask;
		const float3 normal = select(hemi.yzx, select(hemi.zxy, hemi.xyz, uint3(a_mask)), uint3(b_mask));
#endif
		const int3 axis_sign = (int3)(0x80000000) & ray.hit.min_mask;
		const float dist = ray.ray.rcpdir.w;
		const float3 ray_rcpdir = clamp(1.f / as_float3(as_int3(normal) ^ axis_sign), -MAXFLOAT, MAXFLOAT);
		const struct Ray ray = { float4(ray_origin + ray_direction * dist, as_float(result)), float4(ray_rcpdir, MAXFLOAT) };
		result = select(255, 16, occlude(get_octet(src_a, 0), src_b, src_c, &root_bbox, &ray));
	}
	else
		result = 0;

// source_epilogue
    dst.write(result * half(1.0 / 255.0), gid);
}

