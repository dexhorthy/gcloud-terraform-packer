#!/bin/bash

if [ $# -ne 1 ]; then
    echo "USAGE: $0 POOL_IP"
    exit 1
fi

ab -n 10000 -c 200 -s 2 http://$1/

