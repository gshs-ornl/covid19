#!/usr/bin/env bash

echo -e "\e[33m Running tests for covid19scrapers \e[39m"

sleep 20

echo -e "\e[35m selenium is up\e[36m -- executing tests\e[39m"

for f in /tmp/tests/*.py; do
  python3 "$f"
done

#for f in /tmp/tests/*.R; do
  #Rscript "$f"
#done

tail -f /dev/null
