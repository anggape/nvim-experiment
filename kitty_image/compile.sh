#!/usr/bin/env bash

rm -f stb_image.so
cc $(pkg-config --cflags luajit) \
  -std=c99 -O2                   \
  -fPIC -shared                  \
  -o stb_image.so                \
  stb_image.c
