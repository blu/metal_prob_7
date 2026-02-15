Denoising for Humans
====================

Abstract
--------

Path tracing -- the holy grail of rendering, has always been associated with the high computational cost of its pixels. The stochastic nature of the light integration means that noise is an inherent part of the process. Noise removal comes at the cost of multiple samples (ray paths) per pixel, with multiple bounces per path. Techniques like Importance Sampling (IS), Multiple Importance Sampling (MIS) and sample caching improve the quality and/or cost of the samples, but the multiplicity factor still remains between a few tens and a few thousands of samples per pixel, depending on content and lighting complexity on one hand, and on taget fidelity on the other. As a result, low-sample path tracing, while actively sought after, has been hard to attain in practice. A post-tracing solution known as denoising has been gaining traction, where (mostly) DNNs would try to reconstruct a signal from a noisy input.

If we stepped back for a moment to look at the fundamental perception principles of CG, the first thing we'd notice is how they have always relied on the physiological and neurological specifics of human vision. Whether it is the Red-Green-Blue (RGB) pixel primaries targeting our light receptors, or the Luminance-Chrominance encodings which rely on the disparity between our chromatic and achromatic perception, or display resolutions targeting our retinal spatial limits, hardly anything in our CG designs has neglected the physiology or neurology of our eyesight.

An essential aspect of human vision is the temporal one. There too our vision's neurological quirks have been traditionally put to use. For instance non-interactive cinematics can be lifelike at as low as e.g. 24 FPS with the use of sufficient amount of motion blur, while at the same time our vision is capable of discerning momentary shapes flashing for as short as a few thousandths of a second. Such wide temporal capabilities come courtesy of the signal-processing facilities in our occipital lobe -- a computational apparatus formed through eons of evolution.

So a question naturally emerges: Using both the neurilogical spatial *and* temporal specifics of human vision, and knowing that low-cost path tracing is inherently noisy, could we turn this deffect into an effect? Could we turn computationally-cheap stochastic noise into something our vision could interpet as a smooth luminance and/or chrominance spatio-temporal continuum? Or put bluntly, can human vision denoise cheap (i.e. low-quality) path tracing?


Glossary: Samples and Samples-Per-Pixel (SPP)
---------------------------------------------------

In the context of path tracing, i.e. Monte-Carlo Rendering/Stochastic Ray Tracing, *sampling* loosely refers to the act of collecting irradiance information over a pixel through stochastic ray queries. SPP terminology, while commonly used in ray and path tracing, can be confusing, though. The confusion stems from the common use of the term for counting not just any but *camera* (AKA primary) rays per pixel. In this text we adopt a slightly different, more generic meaning of SPP, one which transcends multi- vs single camera rays and recursivity vs iterativity of the implementation. As hinted in the abstract, SPP can be used perfectly soundly to describe the multiplicity of *individual ray paths* per pixel, up to a certain path length. That definition corresponds much closer with the statistical meaning of 'samples' in stochastic computations.

Unless never hitting anything of interest or hitting a pefect black body right off the start, a ray path consists of multiple subsequent segments, separated by "bounces". Namely, segments are straight sections of the path where a ray is cast into space (or participating media), concluding in a path vertex -- a point of reevaluation of the path direction (eventually, a point of path termination). Two ray paths are the same iff their starting vertices and all their subsequent segments match.

Let us try to count paths for recursivity. Imagine a camera ray hitting a diffuse surface (or producing an Ambient Occlusion computation, for that matter) -- that would employ *multi-ray spawning* at this vertex, thus producing a multitude of path continuations. Essentially, for a shared 1st segment and N distinctive 2nd (and final) segments we would get N different paths. Conversely, if for the same diffuse surface N camera rays per pixel spawned 1 secondary ray each, we would get again N different paths. Generally, M primary rays per pixel spawning N secondary and final rays each would give us M * N paths and as many SPP. The same basic combinatorial counting extends to both iteratively- and recursively-evaluated paths of arbitrary length.

'But a recursive implementation starting off with one primary ray would need just one ray query for its first hit, versus N queries for N primary rays!' an alert reader could object. Indeed, but from the POV of counting paths, a recursive implementation is just an elegant way to reuse ray queries along different paths -- a form of memoization. A similar effect could be obtained from sample merging and/or caching techniques over same-iteration vertices across multiple paths. Overall, any such optimisation should not change the count of vertices per individual paths, let alone the path count.


Experiment Setup
----------------

Hereby we will try to produce a setup that employes a basic path-tracing effect -- stochastically-computed World-Space Ambient Occlusion (AO), and present that to the human observer in some highly noisy form. We will try to tell under what conditions, if any, human vision can perceive that as higher fidelity, i.e. of subjectively less noise than we know our setup to entail.

As path-tracing costs come from the multiplicity of samples-per-pixel (SPP), let us first approach that. Among the cheapest and noisiest rendering would be single-sample-per-pixel (1-spp). While nothing stops up from going below 1-spp, or even variable SPP, we will limit ourselves to 1-spp for practical reasons, particularly to avoid discussing foveal-vs-peripheral vision, which is beyond our scope at this stage.

Color-wise, the cheapest possible rendering would be two-tone i.e. limited to two colors. In terms of luminance, which AO is naturally limited to, two-tone rendering would comprise of just two sufficiently distant levels of luma. For normalized luminance that could be zero luma and full luma. So let us focus on two-tonal 1-spp achromatic rendering.

Please note, that this setup would be principally opposite to quantisaiton techniques where we render in high intermediate fiedlity, i.e. high per-pixel cost, and eventually quantize the output to B&W via error dispersion techniques such as dithering. In our approach we would not have hi-fi intermediates to work with -- our highest-grade material will be already B&W and highly noisy. And the only apparatus we will rely on to reconstruct a better-quality signal would be our vision.

Here we should note that pixels are but a convenient abstraction of our spatial setup -- the spatial resolution of human vision is not measured in linear spatial units; optical spatial resolution is inherently angular, taking into account view distance. Still, assuming a normal desktop view distance, we can cancel out any distance considerations from our setup, and rely on linear density metrics like Pixels-per-inch (PPI). Here we have a convienient upper limit, one commonly referred to by the display industry as "retina" desktop pixel densities, i.e. densities between 200 and 300 PPI.


The Temporal Dimension
----------------------

So far we have discussed only the spatial characeristics of our rendering setup -- samples-per-pixel; pixels being quantum elements of abstraction of our spatial perception, and carriers of luma -- something our vision works with. But inherently we are trying to solve a *stohastic integration* problem, so we are *bound* to use multiplicity. As we have severely (and intentionally) degraded our samples-per-pixel, our multiplicity may come from elsewhere.

Hereby we introduce a new metric: samples-per-pixel-per-second, as a practical unit of the generic *samples-per-space-per-time*, that our spatio-temporal vison works with at some reasonable level of abstraction.

So, to narrow down our original question, by how many samples per second do we need to multiply our 1-spp two-tone spatial setup, to start triggering a denoising effect in our vision?


Test Software
-------------

As already established, our setup will compute World-Space AO, stochastically, at 1-spp. What we want to control here is one parameter: samples-per-space-per-time. Translating that into familiar practical terms, that means controlling the rendering output resolution and rendering frequency, or FPS.


Requirements
------------

* MacOS 11 or later on Apple Silicon (arm64)
* Xcode 12 or later

Building
--------

Clone [CG2 2014 demo](https://github.com/ChaosGroup/cg2_2014_demo) into the parent directory of this repo:

```
$ cd ..
$ git clone https://github.com/ChaosGroup/cg2_2014_demo
$ cd -
```

Build project from within Xcode (`cmd-b`) or from the command line:

```
$ xcodebuild -scheme problem_7-macOS -derivedDataPath ./DerivedData -quiet build
```

Invoke executable from Xcode (`cmd-r`) or from the command line (full CLI control) as:

```
$ cd DerivedData/Build/Products/Release/problem_7.app/Contents/MacOS
$ ./problem_7 -help
usage: ./problem_7 [<option> ...]
options (multiple args to an option must constitute a single string, eg. -foo "a b c"):
        -screen <width> <height> <Hz>   : set framebuffer of specified geometry and refresh
        -frames <unsigned_integer>      : set number of frames to run; default is max unsigned int
        -frame_invar_rng                : use frame-invariant RNG for sampling
        -group_size <width> <height>    : set workgroup geometry; default is (execution_width, max_threads_per_group / execution_width)
        -borderful                      : set style of output window to titled; default is borderless
```

Reference Performance (screen CLI)
----------------------------------

| device                          | resolution @ Hz   | OS note      |
| ------------------------------- | ----------------- | ------------ |
| MBA M1 (7-core GPU)             | 2560 x 1600 @ 60  | big sur 11.7 |
| Mac mini M1 (8-core GPU)        | 2560 x 1712 @ 60  | big sur 11.7 |
| Mac mini M1 (8-core GPU)        | 2592 x 1744 @ 60  | sonoma 14.7  |
| Mac Studio M2 Max (30-core GPU) | 3840 x 2160 @ 120 | sequoia 15.2 |
| MBP M3 Max (40-core GPU)        | 3392 x 2176 @ 120 |              |


Please note, that the above Hz values are the top FPS for these resolutions on these devices. One can always go with lower Hz, using integer denominators of the monitor refresh rate. For instance, for a monitor driven by macOS at 120Hz, the Hz denominations would be:

* 120 Hz / 1 = 120 Hz
* 120 Hz / 2 = 60 Hz
* 120 Hz / 3 = 40 Hz
* 120 Hz / 4 = 30 Hz
* 120 Hz / 5 = 24 Hz, etc


Unadulterated 1-spp Stochastics
-------------------------------

To get an idea of what our stochactic-sampling baseline looks like, run the test app with CLI option `-frame_invar_rng` -- that produces a frame-invariant, i.e. time-invariant sampling of an otherwise dynamic AO scene.

Please note, that despite our limitation to 1-spp, we can (and really should) still employ some IS-style techniques to improve the "information value" of our 1-spp. Namely, we use cosine-weighted distribution for the off-surface shooting direction of our AO rays. But that is the baseline in path tracing, so it is all fair.


Scene Content
-------------

The test app contains 3 voxel-comprised scenes, of which one is repeated under a different camera angle, so 4 scenes altogether. To see a full timeline with all scenes one'd need approximately 10K frames at 60 Hz, or 20K frames at 120 Hz, etc. The number of frames is specified via the `-frames` CLI option.
