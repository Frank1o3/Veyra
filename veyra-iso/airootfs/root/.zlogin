# Fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

# Hand execution over to your Rust bootstrapper on TTY1
if [ "$(tty)" = "/dev/tty1" ]; then
    clear
    # exec prevents dropping to a root shell if the user quits the binary
    exec /usr/local/bin/veyra-installer
fi
