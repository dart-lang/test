export DISPLAY=:99.0
sh -e /etc/init.d/xvfb start
t=0; until (xdpyinfo -display :99 &> /dev/null || test $t -gt 10); do sleep 1; let t=$t+1; done
