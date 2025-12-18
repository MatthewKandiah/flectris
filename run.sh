#!/usr/bin/env bash

set -eu

mkdir -p ./build

echo "Compiling shaders..."
glslc -o build/vert.spv shaders/main.vert -g
glslc -o build/frag.spv shaders/main.frag -g

echo "Building main..."
odin build main -out:build/main.bin -debug

echo "Running main..."
./build/main.bin
