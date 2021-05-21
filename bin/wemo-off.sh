#!/usr/bin/env bash

export TZ='America/New_York'

thetime=`date +%D' '%T`

/home/user/.local/bin/wemo  switch "nyar" off 2>/dev/null
echo $thetime "off" >> ~/temperature/log
