#!/bin/bash

DIR=$PWD

mkdir /tmp/upper
mkdir /tmp/work

sudo mount -t overlay overlay -o lowerdir=$DIR,upperdir=/tmp/upper,workdir=/tmp/work  $DIR
