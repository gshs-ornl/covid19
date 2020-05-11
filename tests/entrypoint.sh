#!/usr/bin/env bash
for f in /tmp/test*.py; do
  python3 "$f" -H
done
