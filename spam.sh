#!/bin/bash

if [ $# -ne 1 ]; then
    echo "USAGE: $0 POOL_IP"
    exit 1
fi

for i in {1..10000}; do
    curl $1 --max-time 2 2>/dev/null &
done

wait
