#!/bin/sh

dpkg-query -Wf '${Package;-40}${Priority}\n' | sort -b -k2,2 -k1,1
