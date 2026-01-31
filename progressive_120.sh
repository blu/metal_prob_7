#!/bin/bash

# This script targets M2 Max (30-core GPU) level of performance on a 120Hz display

cd "DerivedData/Build/Products/Release/problem_7.app/Contents/MacOS"

/usr/bin/time ./problem_7 -screen "3840 2160 30"  -frames 500 -frame_invar_rng

/usr/bin/time ./problem_7 -screen "3840 2160 30"  -frames 500  # Hz = 120 / 4
/usr/bin/time ./problem_7 -screen "3840 2160 60"  -frames 1000 # Hz = 120 / 2
/usr/bin/time ./problem_7 -screen "3840 2160 120" -frames 2000 # Hz = 120 / 1
