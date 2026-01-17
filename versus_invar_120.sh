#!/bin/bash

# This script targets M2 Max (30-core GPU) level of performance on a 120Hz display

cd "DerivedData/Build/Products/Release/problem_7.app/Contents/MacOS"

/usr/bin/time ./problem_7 -screen "3456 2160 120" -frames 2000 -frame_invar_rng
/usr/bin/time ./problem_7 -screen "3456 2160 120" -frames 2000
