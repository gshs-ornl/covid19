#!/usr/bin/env sh 
echo "Scheduling py_runner to run every 6 hours starting at $(date +"%H:%M")"
while true; do
  TIMESTAMP=$(date +"%A, %B %d, %Y at %I:%M %p")
  echo "Executing Python Runner: $TIMESTAMP"
  python3 /tmp/py_runner.py
  sleep 21600
done
