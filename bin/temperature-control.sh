#!/usr/bin/env bash

export TZ='America/New_York'

temp=`/home/user/.local/bin/temper-poll | grep Device | awk '{print $3}'| sed 's/°C//'`
when=`date +%s`
thetime=`date +%D' '%T`
hour=`date +%H`

# calibrate temperature
t=`echo "$temp - 0" | bc -l`

# Todo Consider logging into journal instead with logger
#if [ -n "$temp" ]; then
#  echo $when $t $thetime >> ~/temperature/temper.dat
#fi

# Evening hours after 5pm - target 19 °C
if [ $( echo "$hour >= 17 && $hour <= 22 && $t <= 19" | bc ) -eq 1 ]; then
  ~/.dotfiles/.bin/heat-on.sh
fi

# Sleeping hours after midnight - target 16 °C
if [ $( echo "$hour >= 0 && $hour < 8" | bc ) -eq 1 ]; then
  if [ $( echo "$t <= 16" | bc ) -eq 1 ]; then
    ~/.dotfiles/.bin/heat-on.sh
  else
    ~/.dotfiles/.bin/heat-off.sh
  fi
fi

# Always turn off if temperature is above 20 °C
if [ $( echo "$t >= 20.1" | bc ) -eq 1 ]; then
  ~/.dotfiles/.bin/heat-off.sh
fi

# Turn off in the morning
if [ $( echo "$hour >= 7 && $hour <= 11" | bc ) -eq 1 ]; then
  ~/.dotfiles/.bin/heat-off.sh
fi

# gnuplot temper.gplt
