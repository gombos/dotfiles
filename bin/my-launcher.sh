#!/bin/sh

active_window_name=$(xdotool getactivewindow getwindowname)

if echo $active_window_name | grep -i "Google Chrome"
then
  /home/user/.bin/rofi-pass
else
  rofi -combi-modi window,drun -show combi -modi combi
fi
