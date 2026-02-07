#include <sstream>
#include <cassert>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <cmath>

#include "param.h"
#include "timer.h"
#include "vectnative.hpp"
#include "pure_macro.hpp"
#include "scoped.hpp"
#include "stream.hpp"
#include "array.hpp"
#include "problem_6.hpp"

// verify iostream-free status
#if _GLIBCXX_IOSTREAM
#error rogue iostream acquired
#endif

// verify tree minimalism
#if MINIMAL_TREE == 0
#error metal kernels used expect a minimal tree
#endif

namespace stream {

// deferred initialization by main()
in cin;
out cout;
out cerr;

} // namespace stream

const char arg_prefix[]                   = "-";
const char arg_screen[]                   = "screen";
const char arg_frames[]                   = "frames";
const char arg_frame_id_mask[]            = "frame_id_mask";
const char arg_frame_invar_rng[]          = "frame_invar_rng";
const char arg_workgroup_size[]           = "group_size";
const char arg_borderful[]                = "borderful";

namespace testbed {

template < typename T >
class generic_free {
public:
	void operator()(T* arg) {
		assert(0 != arg);
		std::free(arg);
	}
};

} // namespace testbed

static bool
validate_fullscreen(
	const char *const string,
	unsigned &screen_w,
	unsigned &screen_h,
	unsigned &screen_hz) {

	if (0 == string)
		return false;

	unsigned x, y, hz;

	if (3 != sscanf(string, "%u %u %u", &x, &y, &hz))
		return false;

	if (!x || !y || !hz)
		return false;

	screen_w = x;
	screen_h = y;
	screen_hz = hz;

	return true;
}

int parseCLI(
	int argc,
	const char **argv) {

	// we are early into the c++ code; use the occasion to set up cin, cout and cerr substitute streams
	stream::cin.open(stdin);
	stream::cout.open(stdout);
	stream::cerr.open(stderr);

	const size_t prefix_len = std::strlen(arg_prefix);
	bool success = true;

	for (int i = 1; i < argc && success; ++i) {
		if (std::strncmp(argv[i], arg_prefix, prefix_len)) {
			success = false;
			continue;
		}

		if (!std::strcmp(argv[i] + prefix_len, arg_screen)) {
			if (++i == argc || !validate_fullscreen(argv[i], param.image_w, param.image_h, param.image_hz))
				success = false;

			continue;
		}

		if (!std::strcmp(argv[i] + prefix_len, arg_frames)) {
			if (++i == argc || 1 != sscanf(argv[i], "%u", &param.frames))
				success = false;

			continue;
		}

		if (!std::strcmp(argv[i] + prefix_len, arg_frame_id_mask)) {
			if (++i == argc || 1 != sscanf(argv[i], "%x", &param.frame_msk))
				success = false;

			continue;
		}

		if (!std::strcmp(argv[i] + prefix_len, arg_frame_invar_rng)) {
			param.frame_msk = 0;
			continue;
		}

		if (!std::strcmp(argv[i] + prefix_len, arg_workgroup_size)) {
			if (++i == argc || 2 != sscanf(argv[i], "%u %u", &param.group_w, &param.group_h) || param.group_w == 0 || param.group_h == 0)
				success = false;

			continue;
		}

		if (!std::strcmp(argv[i] + prefix_len, arg_borderful)) {
			param.flags |= FLAG_BORDERFUL;
			continue;
		}

		success = false;
	}

	if (!success) {
		stream::cerr << "usage: " << argv[0] << " [<option> ...]\n"
			"options (multiple args to an option must constitute a single string, eg. -foo \"a b c\"):\n"
			"\t" << arg_prefix << arg_screen << " <width> <height> <Hz>\t: set framebuffer of specified geometry and refresh\n"
			"\t" << arg_prefix << arg_frames << " <unsigned_integer>\t: set number of frames to run; default is max unsigned int\n"
			"\t" << arg_prefix << arg_frame_invar_rng << "\t\t: use frame-invariant RNG for sampling\n"
			"\t" << arg_prefix << arg_workgroup_size << " <width> <height>\t: set workgroup geometry; default is (execution_width, max_threads_per_group / execution_width)\n"
			"\t" << arg_prefix << arg_borderful << "\t\t\t: set style of output window to titled; default is borderless\n";

		return 1;
	}

	return 0;
}

static matx4 transpose(const matx4& src) {
	simd::f32x4 r0, r1, r2, r3;
	simd::transpose4x4(src[0], src[1], src[2], src[3], r0, r1, r2, r3);
	return matx4(r0, r1, r2, r3);
}

class matx3_rotate : public matx3 {
	matx3_rotate();

public:
	matx3_rotate(
		const float a,
		const float x,
		const float y,
		const float z) {

		simd::f32x4 sin_ang;
		simd::f32x4 cos_ang;
		simd::sincos(simd::f32x4(a, simd::flag_zero()), sin_ang, cos_ang);

		const float sin_a = sin_ang[0];
		const float cos_a = cos_ang[0];

		m[0] = simd::f32x4(x * x + cos_a * (1 - x * x),         x * y - cos_a * (x * y) + sin_a * z, x * z - cos_a * (x * z) - sin_a * y, simd::flag_zero());
		m[1] = simd::f32x4(y * x - cos_a * (y * x) - sin_a * z, y * y + cos_a * (1 - y * y),         y * z - cos_a * (y * z) + sin_a * x, simd::flag_zero());
		m[2] = simd::f32x4(z * x - cos_a * (z * x) + sin_a * y, z * y - cos_a * (z * y) - sin_a * x, z * z + cos_a * (1 - z * z),         simd::flag_zero());
	}
};


class matx4_rotate : public matx4 {
	matx4_rotate();

public:
	matx4_rotate(
		const float a,
		const float x,
		const float y,
		const float z) {

		simd::f32x4 sin_ang;
		simd::f32x4 cos_ang;
		simd::sincos(simd::f32x4(a, simd::flag_zero()), sin_ang, cos_ang);

		const float sin_a = sin_ang[0];
		const float cos_a = cos_ang[0];

		m[0] = simd::f32x4(x * x + cos_a * (1 - x * x),         x * y - cos_a * (x * y) + sin_a * z, x * z - cos_a * (x * z) - sin_a * y, 0.f);
		m[1] = simd::f32x4(y * x - cos_a * (y * x) - sin_a * z, y * y + cos_a * (1 - y * y),         y * z - cos_a * (y * z) + sin_a * x, 0.f);
		m[2] = simd::f32x4(z * x - cos_a * (z * x) + sin_a * y, z * y - cos_a * (z * y) - sin_a * x, z * z + cos_a * (1 - z * z),         0.f);
		m[3] = simd::f32x4(0.f,                                 0.f,                                 0.f,                                 1.f);
	}
};


static inline float
wrap_at_period(
	const float x,
	const float period) {

	const simd::f32x4 vx = simd::f32x4(x, simd::flag_zero());
	const simd::f32x4 vperiod = simd::f32x4(period, simd::flag_zero());
	const simd::u32x4 mask = vx >= vperiod;
	return x - simd::mask(vperiod, mask)[0];
}


static inline int32_t
reset_at_period(
	const int32_t x,
	const int32_t period) {

	const simd::s32x4 vx = simd::s32x4(x, simd::flag_zero());
	const simd::s32x4 vperiod = simd::s32x4(period, simd::flag_zero());
	const simd::u32x4 mask = vx < vperiod;
	return simd::mask(vx, mask)[0];
}

////////////////////////////////////////////////////////////////////////////////
// scene support
////////////////////////////////////////////////////////////////////////////////

class Scene {
protected:
	// scene offset in model space
	float offset_x;
	float offset_y;
	float offset_z;

	// scene orientation
	float azim; // around z
	float decl; // around x
	float roll; // around y

	// scene camera position
	float cam_x;
	float cam_y;
	float cam_z;

public:
	Scene()
	: offset_x(0.f)
	, offset_y(0.f)
	, offset_z(0.f)
	, azim(0.f)
	, decl(0.f)
	, roll(0.f)
	, cam_x(0.f)
	, cam_y(0.f)
	, cam_z(0.f) {
	}

	virtual bool init(Timeslice& scene) = 0;
	virtual bool frame(Timeslice& scene, const float dt) = 0;

	// scene offset in model space
	float get_offset_x() const {
		return offset_x;
	}

	float get_offset_y() const {
		return offset_y;
	}

	float get_offset_z() const {
		return offset_z;
	}

	// scene orientation
	float get_azim() const {
		return azim;
	}

	float get_decl() const {
		return decl;
	}

	float get_roll() const {
		return roll;
	}

	// scene camera position
	float get_cam_x() const {
		return cam_x;
	}

	float get_cam_y() const {
		return cam_y;
	}

	float get_cam_z() const {
		return cam_z;
	}
};

////////////////////////////////////////////////////////////////////////////////
// Scene1: Deathstar Treadmill
////////////////////////////////////////////////////////////////////////////////

class Scene1 : public virtual Scene {

	// scene camera properties
	float accum_x;
	float accum_y;

	enum {
		grid_rows = 40,
		grid_cols = 20,
		dist_unit = 1
	};

	float accum_time;
	float generation;

	Array< Voxel > content;
	BBox contentBox;

	bool update(
		Timeslice& scene,
		const float generation);

	void camera(
		const float dt);

public:
	Scene1() : contentBox(BBox::flag_noinit()) {}

	// virtual from Scene
	bool init(
		Timeslice& scene);

	// virtual from Scene
	bool frame(
		Timeslice& scene,
		const float dt);
};


bool Scene1::init(
	Timeslice& scene) {

	accum_x = 0.f;
	accum_y = 0.f;
	accum_time = 0.f;
	generation = grid_rows;

	if (!content.setCapacity(grid_rows * grid_cols))
		return false;

	const float unit = dist_unit;
	const float alt = unit * .5f;
	contentBox = BBox();

	for (int y = 0; y < grid_rows; ++y)
		for (int x = 0; x < grid_cols; ++x) {
			const BBox box(
				vect3(x * unit,        y * unit,        0.f),
				vect3(x * unit + unit, y * unit + unit, alt * (rand() % 4 + 1)),
				BBox::flag_direct());

			contentBox.grow(box);
			content.addElement(Voxel(box.get_min(), box.get_max()));
		}

	return scene.set_payload_array(content, contentBox);
}


inline bool Scene1::update(
	Timeslice& scene,
	const float generation) {

	const float unit = dist_unit;
	const float alt = unit * .5f;
	size_t index = 0;
	contentBox = BBox();

	for (index = 0; index < (grid_rows - 1) * grid_cols; ++index) {
		contentBox.grow(content.getElement(index + grid_cols).get_bbox());
		content.getMutable(index) = content.getElement(index + grid_cols);
	}

	const float y = generation;

	for (int x = 0; x < grid_cols; ++x, ++index) {
		const BBox box(
			vect3(x * unit,        y * unit,        0.f),
			vect3(x * unit + unit, y * unit + unit, alt * (rand() % 4 + 1)),
			BBox::flag_direct());

		contentBox.grow(box);
		content.getMutable(index) = Voxel(box.get_min(), box.get_max());
	}

	return scene.set_payload_array(content, contentBox);
}


inline void Scene1::camera(
	const float dt) {

	const float period_x = 3.f; // seconds
	const float period_y = 2.f; // seconds

	const float deviate_x = 1.f / 32.f; // distance
	const float deviate_y = 1.f / 32.f; // distance

	const float roll_factor = 1 / 32.f; // of pi

	accum_x = wrap_at_period(accum_x + dt, period_x);
	accum_y = wrap_at_period(accum_y + dt, period_y);

	simd::f32x4 sin_xy;
	simd::f32x4 cos_x;
	simd::sincos(simd::f32x4(
		accum_x / period_x * float(M_PI * 2.0),
		accum_y / period_y * float(M_PI * 2.0), 0.f, 0.f),
		sin_xy, cos_x);

	cam_x = sin_xy[0] * deviate_x;
	cam_y = sin_xy[1] * deviate_y;
	roll  = cos_x[0] * float(M_PI * roll_factor);
}


bool Scene1::frame(
	Timeslice& scene,
	const float dt) {

	camera(dt);

	const float update_period = .25f;

	offset_y -= dist_unit * dt / update_period;
	accum_time += dt;

	if (accum_time < update_period)
		return scene.set_payload_array(content, contentBox);

	accum_time -= update_period;

	return update(scene, generation++);
}

////////////////////////////////////////////////////////////////////////////////
// Scene2: Sine Floater
////////////////////////////////////////////////////////////////////////////////

class Scene2 : virtual public Scene {

	// scene camera properties
	float accum_x;
	float accum_y;

	enum {
		grid_rows = 20,
		grid_cols = 20,
		dist_unit = 1
	};

	float accum_time;

	Array< Voxel > content;

	bool update(
		Timeslice& scene,
		const float dt);

	void camera(
		const float dt);

public:
	// virtual from Scene
	bool init(
		Timeslice& scene);

	// virtual from Scene
	bool frame(
		Timeslice& scene,
		const float dt);
};


bool Scene2::init(
	Timeslice& scene) {

	accum_x = 0.f;
	accum_y = 0.f;
	accum_time = 0.f;

	if (!content.setCapacity(grid_rows * grid_cols))
		return false;

	const float unit = dist_unit;
	BBox contentBox;

	for (int y = 0; y < grid_rows; ++y)
		for (int x = 0; x < grid_cols; ++x) {
			const BBox box(
				vect3(x * unit,        y * unit,        0.f),
				vect3(x * unit + unit, y * unit + unit, 1.f),
				BBox::flag_direct());

			contentBox.grow(box);
			content.addElement(Voxel(box.get_min(), box.get_max()));
		}

	return scene.set_payload_array(content, contentBox);
}


inline bool Scene2::update(
	Timeslice& scene,
	const float dt) {

	const float period = 2.f; // seconds

	accum_time = wrap_at_period(accum_time + dt, period);

	const float time_factor = simd::sin(simd::f32x4(accum_time / period * float(M_PI * 2.0), simd::flag_zero()))[0];

	const float unit = dist_unit;
	const float alt = unit * .5f;
	size_t index = 0;
	BBox contentBox;

	for (int y = 0; y < grid_rows; ++y)
		for (int x = 0; x < grid_cols; ++x, ++index) {
			const simd::f32x4 sin_xy = simd::sin(simd::f32x4(x * alt, y * alt, 0.f, 0.f));
			const BBox box(
				vect3(x * unit,        y * unit,        0.f),
				vect3(x * unit + unit, y * unit + unit, 1.f + time_factor * unit * (sin_xy[0] * sin_xy[1])),
				BBox::flag_direct());

			contentBox.grow(box);
			content.getMutable(index) = Voxel(box.get_min(), box.get_max());
		}

	return scene.set_payload_array(content, contentBox);
}


inline void Scene2::camera(
	const float dt) {

	const float period_x = 3.f; // seconds
	const float period_y = 2.f; // seconds

	const float deviate_x = 1.f / 32.f; // distance
	const float deviate_y = 1.f / 32.f; // distance

	const float roll_factor = 1 / 32.f; // of pi

	accum_x = wrap_at_period(accum_x + dt, period_x);
	accum_y = wrap_at_period(accum_y + dt, period_y);

	simd::f32x4 sin_xy;
	simd::f32x4 cos_x;
	simd::sincos(simd::f32x4(
		accum_x / period_x * float(M_PI * 2.0),
		accum_y / period_y * float(M_PI * 2.0), 0.f, 0.f),
		sin_xy, cos_x);

	cam_x = sin_xy[0] * deviate_x;
	cam_y = sin_xy[1] * deviate_y;
	roll  = cos_x[0] * float(M_PI * roll_factor);
}


bool Scene2::frame(
	Timeslice& scene,
	const float dt) {

	camera(dt);

	return update(scene, dt);
}

////////////////////////////////////////////////////////////////////////////////
// Scene3: Serpents
////////////////////////////////////////////////////////////////////////////////

class Scene3 : virtual public Scene {

	// scene camera properties
	float accum_x;
	float accum_y;

	enum {
		queue_length = 96,
		main_radius = 8,
	};

	float accum_time;

	Array< Voxel > content;

	bool update(
		Timeslice& scene,
		const float dt);

public:
	// virtual from Scene
	bool init(
		Timeslice& scene);

	// virtual from Scene
	bool frame(
		Timeslice& scene,
		const float dt);
};


bool Scene3::init(
	Timeslice& scene) {

	offset_x = 10.f; // matching the center of scene_1
	offset_y = 10.f; // matching the center of scene_1

	accum_x = 0.f;
	accum_y = 0.f;
	accum_time = 0.f;

	if (!content.setCapacity(queue_length * 2 + 1))
		return false;

	const float radius = main_radius;
	BBox contentBox;

	for (int i = 0; i < queue_length; ++i) {
		const float angle = float(M_PI * 2.0) * (i / float(queue_length));
		const float sin_i = simd::sin(simd::f32x4(i / float(queue_length) * float(M_PI * 16.0), simd::flag_zero()))[0];

		{
			const matx3_rotate rot(angle, 0.f, 0.f, 1.f);
			const vect3 pos = vect3(radius + sin_i, 0.f, sin_i) * rot;
			const BBox box(
				pos - vect3(.5f),
				pos + vect3(.5f),
				BBox::flag_direct());

			contentBox.grow(box);
			content.addElement(Voxel(box.get_min(), box.get_max()));
		}
		{
			const matx3_rotate rot(-angle, 0.f, 0.f, 1.f);
			const vect3 pos = vect3(radius * .5f + sin_i, 0.f, sin_i) * rot;
			const BBox box(
				pos - vect3(.25f),
				pos + vect3(.25f),
				BBox::flag_direct());

			contentBox.grow(box);
			content.addElement(Voxel(box.get_min(), box.get_max()));
		}
	}

	const BBox box(
		vect3(-main_radius, -main_radius, -.25f),
		vect3(+main_radius, +main_radius, +.25f),
		BBox::flag_direct());

	contentBox.grow(box);
	content.addElement(Voxel(box.get_min(), box.get_max()));

	return scene.set_payload_array(content, contentBox);
}


inline bool Scene3::update(
	Timeslice& scene,
	const float dt) {

	const float period = 32.f; // seconds

	accum_time = wrap_at_period(accum_time + dt, period);

	const float radius = main_radius;
	size_t index = 0;
	BBox contentBox;

	for (int i = 0; i < queue_length; ++i, index += 2) {
		const float angle = float(M_PI * 2.0) * (i / float(queue_length)) + accum_time * float(M_PI * 2.0) / period;
		const simd::f32x4 sin_iz = simd::sin(simd::f32x4(
			i / float(queue_length) * float(M_PI * 16.0),
			i / float(queue_length) * float(M_PI * 16.0) + accum_time * float(M_PI * 32.0) / period, 0.f, 0.f));
		const float sin_i = sin_iz[0];
		const float sin_z = sin_iz[1];

		{
			const matx3_rotate rot(angle, 0.f, 0.f, 1.f);
			const vect3 pos = vect3(radius + sin_i, 0.f, sin_z) * rot;
			const BBox box(
				pos - vect3(.5f),
				pos + vect3(.5f),
				BBox::flag_direct());

			contentBox.grow(box);
			content.getMutable(index + 0) = Voxel(box.get_min(), box.get_max());
		}
		{
			const matx3_rotate rot(-angle, 0.f, 0.f, 1.f);
			const vect3 pos = vect3(radius * .5f + sin_i, 0.f, sin_z) * rot;
			const BBox box(
				pos - vect3(.35f),
				pos + vect3(.35f),
				BBox::flag_direct());

			contentBox.grow(box);
			content.getMutable(index + 1) = Voxel(box.get_min(), box.get_max());
		}
	}

	// account for the last element which is never updated
	contentBox.grow(content.getElement(index).get_bbox());

	return scene.set_payload_array(content, contentBox);
}


bool Scene3::frame(
	Timeslice& scene,
	const float dt) {

	return update(scene, dt);
}


enum {
	scene_1,
	scene_2,
	scene_3,

	scene_count
};

////////////////////////////////////////////////////////////////////////////////
// the global control state
////////////////////////////////////////////////////////////////////////////////

namespace c {
	static const float beat_period = 1.714288; // seconds

	static size_t scene_selector;

	// scene properties
	static float decl = 0.f;
	static float azim = 0.f;

	// camera properties
	static float pos_x = 0.f;
	static float pos_y = 0.f;
	static float pos_z = 0.f;

	// accumulators
	static float accum_time = 0.f;
	static float accum_beat = 0.f;
	static float accum_beat_2 = 0.f;

	// view properties
	static float contrast_middle = .5f;
	static float contrast_k = 1.f;
	static float blur_split = -1.f;

} // namespace c

////////////////////////////////////////////////////////////////////////////////
// scripting support
////////////////////////////////////////////////////////////////////////////////

class Action {
protected:
	float lifespan;

public:
	// start the action; return true if action is alive after the start
	virtual bool start(
		const float delay,
		const float duration) = 0;

	// perform action at tick (ie. at frame); return true if action still alive
	virtual bool frame(
		const float dt) = 0;
};

////////////////////////////////////////////////////////////////////////////////
// ActionSetScene1: establish scene_1
////////////////////////////////////////////////////////////////////////////////

class ActionSetScene1 : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionSetScene1::start(
	const float,
	const float) {

	c::scene_selector = scene_1;

	c::pos_x = 0.f;
	c::pos_y = .25f;
	c::pos_z = .875f;

	c::decl = M_PI / -2.0;

	return false;
}


bool ActionSetScene1::frame(
	const float) {

	return false;
}

////////////////////////////////////////////////////////////////////////////////
// ActionSetScene2: establish scene_2
////////////////////////////////////////////////////////////////////////////////

class ActionSetScene2 : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionSetScene2::start(
	const float,
	const float) {

	c::scene_selector = scene_2;

	c::pos_x = 0.f;
	c::pos_y = .25f;
	c::pos_z = 1.f;

	c::decl = M_PI / -2.0;

	return false;
}


bool ActionSetScene2::frame(
	const float) {

	return false;
}

////////////////////////////////////////////////////////////////////////////////
// ActionSetScene3: establish scene_3
////////////////////////////////////////////////////////////////////////////////

class ActionSetScene3 : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionSetScene3::start(
	const float,
	const float) {

	c::scene_selector = scene_3;

	c::pos_x = 0.f;
	c::pos_y = 0.f;
	c::pos_z = 1.125f;

	c::decl = M_PI / -2.125;

	return false;
}


bool ActionSetScene3::frame(
	const float) {

	return false;
}

////////////////////////////////////////////////////////////////////////////////
// ActionViewBlur: blur the view
////////////////////////////////////////////////////////////////////////////////

class ActionViewBlur : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionViewBlur::start(
	const float,
	const float) {

	c::blur_split = -1.f;

	return false;
}


bool ActionViewBlur::frame(
	const float) {

	return false;
}

////////////////////////////////////////////////////////////////////////////////
// ActionViewUnblur: de-blur the view
////////////////////////////////////////////////////////////////////////////////

class ActionViewUnblur : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionViewUnblur::start(
	const float,
	const float) {

	c::blur_split = 1.f;

	return false;
}


bool ActionViewUnblur::frame(
	const float) {

	return false;
}

////////////////////////////////////////////////////////////////////////////////
// ActionViewBlurDt: blur the view non-instantaneously
////////////////////////////////////////////////////////////////////////////////

class ActionViewBlurDt : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionViewBlurDt::start(
	const float delay,
	const float) {

	c::blur_split -= (2.0 / c::beat_period) * delay;

	if (c::blur_split > -1.f)
		return true;

	c::blur_split = -1.f;
	return false;
}


bool ActionViewBlurDt::frame(
	const float dt) {

	c::blur_split -= (2.0 / c::beat_period) * dt;

	if (c::blur_split > -1.f)
		return true;

	c::blur_split = -1.f;
	return false;
}

////////////////////////////////////////////////////////////////////////////////
// ActionViewUnblurDt: de-blur the view non-instantaneously
////////////////////////////////////////////////////////////////////////////////

class ActionViewUnblurDt : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionViewUnblurDt::start(
	const float delay,
	const float) {

	c::blur_split += (2.0 / c::beat_period) * delay;

	if (c::blur_split < 1.f)
		return true;

	c::blur_split = 1.f;
	return false;
}


bool ActionViewUnblurDt::frame(
	const float dt) {

	c::blur_split += (2.0 / c::beat_period) * dt;

	if (c::blur_split < 1.f)
		return true;

	c::blur_split = 1.f;
	return false;
}

////////////////////////////////////////////////////////////////////////////////
// ActionViewSplit: split view in sync to the beat
////////////////////////////////////////////////////////////////////////////////

class ActionViewSplit : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionViewSplit::start(
	const float delay,
	const float duration) {

	if (delay >= duration)
		return false;

	c::blur_split = simd::sin(simd::f32x4(c::accum_beat * float(M_PI * 2.0 / c::beat_period), simd::flag_zero()))[0] * .25f;

	lifespan = duration - delay;
	return true;
}


bool ActionViewSplit::frame(
	const float dt) {

	if (dt >= lifespan)
		return false;

	c::blur_split = simd::sin(simd::f32x4(c::accum_beat * float(M_PI * 2.0 / c::beat_period), simd::flag_zero()))[0] * .25f;

	lifespan -= dt;
	return true;
}

////////////////////////////////////////////////////////////////////////////////
// ActionContrastBeat: pulse contrast to the beat
////////////////////////////////////////////////////////////////////////////////

class ActionContrastBeat : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionContrastBeat::start(
	const float delay,
	const float duration) {

	if (delay >= duration)
		return false;

	c::contrast_middle = .5f;
	c::contrast_k = 1.f + simd::pow(simd::sin(simd::abs(simd::f32x4(float(-M_PI_2) + float(M_PI) * c::accum_beat / c::beat_period, simd::flag_zero()))), simd::f32x4(64.f))[0];

	lifespan = duration - delay;
	return true;
}


bool ActionContrastBeat::frame(
	const float dt) {

	if (dt >= lifespan) {
		c::contrast_middle = .5f;
		c::contrast_k = 1.f;
		return false;
	}

	c::contrast_k = 1.f + simd::pow(simd::sin(simd::abs(simd::f32x4(float(-M_PI_2) + float(M_PI) * c::accum_beat / c::beat_period, simd::flag_zero()))), simd::f32x4(64.f))[0];

	lifespan -= dt;
	return true;
}

////////////////////////////////////////////////////////////////////////////////
// ActionCameraSnake: snake-style camera azimuth (singe quadrant only)
////////////////////////////////////////////////////////////////////////////////

class ActionCameraSnake : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionCameraSnake::start(
	const float delay,
	const float duration) {

	if (delay >= duration)
		return false;

	c::azim += simd::sin(simd::f32x4(c::accum_beat_2 * float(M_PI / c::beat_period), simd::flag_zero()))[0] * float(M_PI / 4.0) * delay;

	lifespan = duration - delay;
	return true;
}


bool ActionCameraSnake::frame(
	const float dt) {

	if (dt >= lifespan)
		return false;

	c::azim += simd::sin(simd::f32x4(c::accum_beat_2 * float(M_PI / c::beat_period), simd::flag_zero()))[0] * float(M_PI / 4.0) * dt;

	lifespan -= dt;
	return true;
}

////////////////////////////////////////////////////////////////////////////////
// ActionCameraBounce: snake-style camera azimuth (full range)
////////////////////////////////////////////////////////////////////////////////

class ActionCameraBounce : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionCameraBounce::start(
	const float delay,
	const float duration) {

	if (delay >= duration)
		return false;

	c::azim += simd::cos(simd::f32x4(c::accum_beat_2 * float(M_PI / c::beat_period), simd::flag_zero()))[0] * float(M_PI / 4.0) * delay;

	lifespan = duration - delay;
	return true;
}


bool ActionCameraBounce::frame(
	const float dt) {

	if (dt >= lifespan)
		return false;

	c::azim += simd::cos(simd::f32x4(c::accum_beat_2 * float(M_PI / c::beat_period), simd::flag_zero()))[0] * float(M_PI / 4.0) * dt;

	lifespan -= dt;
	return true;
}

////////////////////////////////////////////////////////////////////////////////
// ActionCameraBnF: camera position back'n'forth
////////////////////////////////////////////////////////////////////////////////

class ActionCameraBnF : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionCameraBnF::start(
	const float delay,
	const float duration) {

	if (delay >= duration)
		return false;

	c::pos_z += simd::cos(simd::f32x4(c::accum_beat_2 * float(M_PI / c::beat_period), simd::flag_zero()))[0] * delay;

	lifespan = duration - delay;
	return true;
}


bool ActionCameraBnF::frame(
	const float dt) {

	if (dt >= lifespan)
		return false;

	c::pos_z += simd::cos(simd::f32x4(c::accum_beat_2 * float(M_PI / c::beat_period), simd::flag_zero()))[0] * dt;

	lifespan -= dt;
	return true;
}

////////////////////////////////////////////////////////////////////////////////
// ActionCameraLean: camera leaning forth then back
////////////////////////////////////////////////////////////////////////////////

class ActionCameraLean : virtual public Action {
public:
	// virtual from Action
	bool start(const float, const float);

	// virtual from Action
	bool frame(const float);
};


bool ActionCameraLean::start(
	const float delay,
	const float duration) {

	if (delay >= duration)
		return false;

	c::decl += simd::sin(simd::f32x4(c::accum_beat_2 * float(M_PI / c::beat_period), simd::flag_zero()))[0] * delay;

	lifespan = duration - delay;
	return true;
}


bool ActionCameraLean::frame(
	const float dt) {

	if (dt >= lifespan)
		return false;

	c::decl += simd::sin(simd::f32x4(c::accum_beat_2 * float(M_PI / c::beat_period), simd::flag_zero()))[0] * dt;

	lifespan -= dt;
	return true;
}


cli_param param;

namespace { // anonymous

Scene1 scene1;
Scene2 scene2;
Scene3 scene3;

Scene* const scene[] = {
	&scene1,
	&scene2,
	&scene3
};

ActionSetScene1    actionSetScene1;
ActionSetScene2    actionSetScene2;
ActionSetScene3    actionSetScene3;
ActionContrastBeat actionContrastBeat;
ActionViewBlur     actionViewBlur;
ActionViewUnblur   actionViewUnblur;
ActionViewBlurDt   actionViewBlurDt;
ActionViewUnblurDt actionViewUnblurDt;
ActionViewSplit    actionViewSplit;
ActionCameraSnake  actionCameraSnake;
ActionCameraBounce actionCameraBounce;
ActionCameraBnF    actionCameraBnF;
ActionCameraLean   actionCameraLean;

// master track of the application (entries sorted by start time)
const struct {
	const float start;    // seconds
	const float duration; // seconds
	Action& action;
}
track[] = {
	{   0.f,        0.f,      actionSetScene1 },
	{   0.f,        9.428584, actionViewSplit },
	{   0.f,       68.571342, actionContrastBeat },
	{   9.428584,   0.f,      actionViewBlurDt },
	{  68.571342,   0.f,      actionSetScene2 },
	{  68.571342,   0.f,      actionViewUnblur },
	{  68.571342,  27.426758, actionCameraBounce },
	{  82.285824,  6.8551240, actionCameraLean },
	{  95.998100,   0.f,      actionSetScene3 },
	{  95.998100,  39.430652, actionCameraSnake },
	{ 109.714432,  25.714320, actionCameraBnF },
	{ 133.714464,   0.f,      actionViewBlurDt },
	{ 135.428752,   0.f,      actionSetScene1 },
	{ 136.285896,  56.571504, actionContrastBeat },
	{ 198.f,        0.f,      actionViewUnblurDt }
};

const size_t octet_w = 2;
const size_t octet_h = 4096;

const size_t mem_size_octet = octet_w * octet_h * sizeof(simd::u16x4);
const size_t octet_count = mem_size_octet / sizeof(simd::u16x4[2]);

const size_t leaf_w = 4;
const size_t leaf_h = 4096;

const size_t mem_size_leaf = leaf_w * leaf_h * sizeof(simd::u16x4);
const size_t leaf_count = mem_size_leaf / sizeof(simd::u16x4[4]);

const size_t voxel_w = 2;
const size_t voxel_h = 4096;

const size_t mem_size_voxel = voxel_w * voxel_h * sizeof(simd::f32x4);
const size_t voxel_count = mem_size_voxel / sizeof(simd::f32x4[2]);

const size_t carb_w = 1;
const size_t carb_h = 6;

const size_t mem_size_carb = carb_w * carb_h * sizeof(simd::f32x4);
const size_t carb_count = mem_size_carb / sizeof(simd::f32x4);

Array< Timeslice > timeline;

size_t track_cursor;
Action* action[8];
size_t action_count;

simd::f32x4 bbox_min;
simd::f32x4 bbox_max;
simd::f32x4 centre;
simd::f32x4 extent;
float max_extent;

} // namespace anonymous

int content_init(content_init_arg *arg)
{
	using testbed::scoped_ptr;
	using testbed::generic_free;

	// octet map element:
	// struct Octet {
	//     OctetId child[8]; // OctetId := ushort
	// }
	// represent in image as: ushort4 child[2]
	scoped_ptr< void, generic_free > octet_map(std::malloc(mem_size_octet));

	if (nullptr == octet_map()) {
		stream::cerr << "error allocating octet_map\n";
		return -1;
	}

	// leaf map element:
	// struct Leaf {
	//     PayloadId start[8]; // PayloadId := ushort
	//     PayloadId count[8]; // PayloadId := ushort
	// }
	// represent in image as: ushort4 start[2], ushort4 count[2]
	scoped_ptr< void, generic_free > leaf_map(std::malloc(mem_size_leaf));

	if (nullptr == leaf_map()) {
		stream::cerr << "error allocating leaf_map\n";
		return -1;
	}

	// voxel map element:
	// struct BBox {
	//     float min[3];
	//     uint32 min_cookie;
	//     float max[3];
	//     uint32 max_cookie;
	// }
	// represent in image as: float4 min, float4 max
	scoped_ptr< void, generic_free > voxel_map(std::malloc(mem_size_voxel));

	if (nullptr == voxel_map()) {
		stream::cerr << "error allocating voxel_map\n";
		return -1;
	}

	// prepare the playfield ///////////////////////////////////////////////////
	timeline.setCapacity(scene_count);
	timeline.addMultiElement(scene_count);

	// allow scenes to compute their initial params, for us to inquire their prelim info

	// set initial external storage to the octree of the 1st scene
	// note: practically all buffers of the octree require 16-byte alignment; since this is
	// guaranteed by 64-bit malloc, we don't do anything WRT alignment here /32-bit caveat
	// note: all we need from the tree of each scene prior to frame loop is the root bbox;
	// let the trees of all scenes overwrite each other in the same buffer /practical cheat
	timeline.getMutable(scene_1).set_extrnal_storage(
		octet_count, octet_map(),
		leaf_count, leaf_map(),
		voxel_count, voxel_map());

	// set initial external storage to the octree of the 2nd scene (same as storage for 1st and 3rd scenes)
	timeline.getMutable(scene_2).set_extrnal_storage(
		octet_count, octet_map(),
		leaf_count, leaf_map(),
		voxel_count, voxel_map());

	// set initial external storage to the octree of the 3rd scene (same as storage for 1st and 2nd scenes)
	timeline.getMutable(scene_3).set_extrnal_storage(
		octet_count, octet_map(),
		leaf_count, leaf_map(),
		voxel_count, voxel_map());

	if (!scene1.init(timeline.getMutable(scene_1)))
		return 1;

	if (!scene2.init(timeline.getMutable(scene_2)))
		return 2;

	if (!scene3.init(timeline.getMutable(scene_3)))
		return 3;

	track_cursor = 0;
	action_count = 0;

	// use first scene's initial world bbox to compute a normalization (pan_n_zoom) matrix
	const BBox& world_bbox = timeline.getElement(scene_1).get_root_bbox();

	bbox_min = world_bbox.get_min();
	bbox_max = world_bbox.get_max() * simd::f32x4(1.f, .5f, 1.f, 1.f);
	centre = (bbox_max + bbox_min) * simd::f32x4(.5f);
	extent = (bbox_max - bbox_min) * simd::f32x4(.5f);
	max_extent = std::max(extent[0], std::max(extent[1], extent[2]));

	size_t buf_idx = 0;
	arg->buffer_size[buf_idx++] = mem_size_octet;
	arg->buffer_size[buf_idx++] = mem_size_leaf;
	arg->buffer_size[buf_idx++] = mem_size_voxel;
	arg->buffer_size[buf_idx++] = mem_size_carb;

	assert(buffer_designation_count == buf_idx);

	return 0;
}

int content_deinit(void)
{
	return 0;
}

int content_frame(content_frame_arg arg, const uint32_t frame)
{
	const uint32_t image_w = param.image_w;
	const uint32_t image_h = param.image_h;
	const uint32_t fmask   = param.frame_msk;

	void *octet_map_buffer = arg.buffer[buffer_octet];
	void *leaf_map_buffer  = arg.buffer[buffer_leaf];
	void *voxel_map_buffer = arg.buffer[buffer_voxel];
	void *carb_map_buffer  = arg.buffer[buffer_carb];

#if FRAME_RATE == 0
	static uint64_t tlast;
	const uint64_t tframe = timer_ns();

	if (0 == frame)
		tlast = tframe;

	const float dt = double(tframe - tlast) * 1e-9;
	tlast = tframe;

#else
	const float dt = 1.0 / FRAME_RATE;

#endif
	// upate run time (we aren't supposed to run long - fp32 should do) and beat time
	c::accum_time += dt;
	c::accum_beat   = wrap_at_period(c::accum_beat   + dt, c::beat_period);
	c::accum_beat_2 = wrap_at_period(c::accum_beat_2 + dt, c::beat_period * 2.0);

	// run all live actions, retiring the completed ones
	for (size_t i = 0; i < action_count; ++i)
		if (!action[i]->frame(dt))
			action[i--] = action[--action_count];

	// start any pending actions
	for (; track_cursor < COUNT_OF(track) && c::accum_time >= track[track_cursor].start; ++track_cursor)
		if (track[track_cursor].action.start(c::accum_time - track[track_cursor].start, track[track_cursor].duration)) {
			if (action_count == COUNT_OF(action)) {
				stream::cerr << "error: too many pending actions\n";
				return 999;
			}

			action[action_count++] = &track[track_cursor].action;
		}

	// set proper external storage to the octree of the live scene
	// note: practically all buffers of the octree require 16-byte alignment; since this is
	// guaranteed by 64-bit malloc, we don't do anything WRT alignment here /32-bit caveat
	timeline.getMutable(c::scene_selector).set_extrnal_storage(
		octet_count, octet_map_buffer,
		leaf_count, leaf_map_buffer,
		voxel_count, voxel_map_buffer);

	// run the live scene
	if (!scene[c::scene_selector]->frame(timeline.getMutable(c::scene_selector), dt))
		stream::cerr << "failure building frame " << frame << '\n';

	// produce camera for the new frame;
	// collapse S * T and T * S operators as follows:
	//
	//	s	0	0	0		1	0	0	0		s	0	0	0
	//	0	s	0	0	*	0	1	0	0	=	0	s	0	0
	//	0	0	s	0		0	0	1	0		0	0	s	0
	//	0	0	0	1		x	y	z	1		x	y	z	1
	//
	//	1	0	0	0		s	0	0	0		s	0	0	0
	//	0	1	0	0	*	0	s	0	0	=	0	s	0	0
	//	0	0	1	0		0	0	s	0		0	0	s	0
	//	x	y	z	1		0	0	0	1		sx	sy	sz	1

	// forward: pan * zoom * rot * eyep
	// inverse: (eyep)-1 * rotT * (zoom)-1 * (pan)-1

	const matx4 rot =
		matx4_rotate(scene[c::scene_selector]->get_roll(),           0.f, 1.f, 0.f) *
		matx4_rotate(scene[c::scene_selector]->get_azim() + c::azim, 0.f, 0.f, 1.f) *
		matx4_rotate(scene[c::scene_selector]->get_decl() + c::decl, 1.f, 0.f, 0.f);

	const matx4 eyep(
		1.f, 0.f, 0.f, 0.f,
		0.f, 1.f, 0.f, 0.f,
		0.f, 0.f, 1.f, 0.f,
		scene[c::scene_selector]->get_cam_x() + c::pos_x,
		scene[c::scene_selector]->get_cam_y() + c::pos_y,
		scene[c::scene_selector]->get_cam_z() + c::pos_z, 1.f);

	const matx4 zoom_n_pan(
		max_extent, 0.f, 0.f, 0.f,
		0.f, max_extent, 0.f, 0.f,
		0.f, 0.f, max_extent, 0.f,
		centre[0] - scene[c::scene_selector]->get_offset_x(),
		centre[1] - scene[c::scene_selector]->get_offset_y(),
		centre[2] - scene[c::scene_selector]->get_offset_z(), 1.f);

	const matx4 mv_inv = eyep * transpose(rot) * zoom_n_pan;

	vect3 (& carb)[carb_count] = *reinterpret_cast< vect3 (*)[carb_count] >(carb_map_buffer);
	// camera
	carb[0] = vect3(mv_inv[0][0], mv_inv[0][1], mv_inv[0][2]) * vect3(float(image_w) / image_h);
	carb[1] = vect3(mv_inv[1][0], mv_inv[1][1], mv_inv[1][2]) * vect3(-1); // origin in Metal view is upper left corner
	carb[2] = vect3(mv_inv[2][0], mv_inv[2][1], mv_inv[2][2]) * vect3(-1);
	carb[3] = vect3(mv_inv[3][0], mv_inv[3][1], mv_inv[3][2]);
	// root bbox
	carb[4] = timeline.getElement(c::scene_selector).get_root_bbox().get_min();
	carb[5] = timeline.getElement(c::scene_selector).get_root_bbox().get_max();
	// frame id
	const uint32_t masked_frame = frame & fmask;
	carb[5].set(3, reinterpret_cast< const float& >(masked_frame));

	return 0;
}
