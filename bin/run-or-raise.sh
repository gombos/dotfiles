#!/bin/sh
wmctrl -x -a "$1" || $2
