Requirements
------------

* MacOS 11 or later on Apple Silicon (arm64)
* XCode 12 or later

Building
--------

Clone [CG2 2014 demo](https://github.com/ChaosGroup/cg2_2014_demo) into the parent directory of this repo:

```
$ cd ..
$ git clone https://github.com/ChaosGroup/cg2_2014_demo
$ cd -
```

Build project from within XCode (`cmd-b`) or from the command line:

```
$ xcodebuild -scheme problem_7-macOS -derivedDataPath ./DerivedData -quiet build
```

Invoke executable from XCode (`cmd-r`) or from the command line (full CLI control) as:  

```
$ cd DerivedData/Build/Products/Release/problem_7.app/Contents/MacOS
$ ./problem_7 -help
usage: ./problem_7 [<option> ...]
options (multiple args to an option must constitute a single string, eg. -foo "a b c"):
        -screen <width> <height> <Hz>   : set framebuffer of specified geometry and refresh
        -frames <unsigned_integer>      : set number of frames to run; default is max unsigned int
        -frame_invar_rng                : use frame-invariant RNG for sampling
        -group_size <width> <height>    : set workgroup geometry; default is (execution_width, max_threads_per_group / execution_width)
```

Reference Performance (screen CLI)
----------------------------------

| device                     | resolution @ Hz   |
| -------------------------- | ----------------- |
| Apple M1 (7-core GPU)      | 2560 x 1600 @ 60  |
| Apple M1 (8-core GPU)      | 2560 x 1728 @ 60  |
| Apple M2 Max (30-core GPU) | 3456 x 2160 @ 120 |
| Apple M2 Max (38-core GPU) | 3840 x 2160 @ 120 |
