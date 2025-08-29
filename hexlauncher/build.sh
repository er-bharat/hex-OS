#!/bin/bash

set -e

# Create and enter build directory
mkdir -p build
cd build

# Run CMake
cmake .. -DCMAKE_BUILD_TYPE=Release

# Build the project
cmake --build . -j$(nproc)

# Go back and run the app
cd ..
./build/hexlauncher
