#!/usr/bin/env bash

set -eu

echo "Compiling shaders..."
glslc -o vert.spv shaders/main.vert -g
glslc -o frag.spv shaders/main.frag -g

echo "Running main..."
odin run main -debug
