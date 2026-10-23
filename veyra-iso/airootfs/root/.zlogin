# Fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

# Start the guided shell installer automatically on the first console.
if [ "$(tty)" = "/dev/tty1" ]; then
    stty sane
    /usr/local/bin/veyra-installer.sh
fi
