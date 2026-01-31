#!/bin/bash

# This script targets M1 (8-core GPU) level of performance on a 60Hz display

cd "DerivedData/Build/Products/Release/problem_7.app/Contents/MacOS"

/usr/bin/time ./problem_7 -screen "2560 1712 30"  -frames 500  # Hz = 60 / 2
/usr/bin/time ./problem_7 -screen "2560 1712 60"  -frames 1000 # Hz = 60 / 1
