#!/usr/bin/env bash
for file in ../scripts/*; do
  [ -f "$file" ] && [ -x "$file" ] && "$file"
done
