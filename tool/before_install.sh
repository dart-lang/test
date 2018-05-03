mkdir -p bin
export PATH="$PATH:`pwd`/bin/"
ln -s `which chromium-browser` bin/google-chrome

export DISPLAY=:99.0
sh -e /etc/init.d/xvfb start
t=0; until (xdpyinfo -display :99 &> /dev/null || test $t -gt 10); do sleep 1; let t=$t+1; done
