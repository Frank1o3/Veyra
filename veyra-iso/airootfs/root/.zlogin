# Fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

# Hand execution over to your Rust bootstrapper on TTY1
if [ "$(tty)" = "/dev/tty1" ]; then
    echo "this is from .zlogin, launching at $(date)" >> /tmp/zlogin.log
    stty sane
    /usr/local/bin/veyra-installer 2>>/tmp/veyra-installer.log
    echo "veyra-installer exited with code $?" >> /tmp/zlogin.log
fi
