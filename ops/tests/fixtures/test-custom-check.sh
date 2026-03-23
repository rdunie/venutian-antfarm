#!/usr/bin/env bash
grep -q "FIXME" "$1" && echo "BLOCKED: FIXME found" && exit 2
exit 0
