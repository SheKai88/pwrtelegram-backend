#!/bin/bash

if [ "$1" == "start" ];then tmux kill-session -t pwrtelegram &>/dev/null; tmux new-session -s pwrtelegram -d caddy;fi
[ "$1" == "stop" ] && tmux kill-session -t pwrtelegram

