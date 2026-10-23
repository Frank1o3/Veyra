#!/bin/bash

STATE_FILE="/tmp/audio-toggle-state"

SINK_HEADPHONES="alsa_output.pci-0000_00_1b.0.analog-stereo"
SINK_SOUNDBAR="alsa_output.usb-Dell_Dell_AC511_USB_SoundBar-00.analog-stereo"
COMBINED_SINK="combined_output"

STATE=$(cat "$STATE_FILE" 2>/dev/null)

if [ "$STATE" == "hp" ]; then
    TARGET_SINK="$SINK_SOUNDBAR"
    NOTIFY_MSG="🔊 Soundbar Only"
    echo "sb" > "$STATE_FILE"

elif [ "$STATE" == "sb" ]; then

    # create combined sink if missing
    if ! pactl list short sinks | grep -q "$COMBINED_SINK"; then
        pactl load-module module-combine-sink \
            sink_name=$COMBINED_SINK \
            slaves=$SINK_HEADPHONES,$SINK_SOUNDBAR \
            sink_properties=device.description="Combined_Output"
    fi

    TARGET_SINK="$COMBINED_SINK"
    NOTIFY_MSG="🔊🎧 Both Outputs"
    echo "both" > "$STATE_FILE"

else
    TARGET_SINK="$SINK_HEADPHONES"
    NOTIFY_MSG="🎧 Headphones Only"
    echo "hp" > "$STATE_FILE"
fi

# Apply sink
pactl set-default-sink "$TARGET_SINK"

# Move audio streams
pactl list short sink-inputs | awk '{print $1}' | \
xargs -r -I {} pactl move-sink-input {} "$TARGET_SINK"

notify-send -t 2000 "Audio Output" "$NOTIFY_MSG"