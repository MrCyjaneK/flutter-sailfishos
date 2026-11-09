#!/bin/sh
export LD_LIBRARY_PATH=/usr/share/hello-sfos/lib:/usr/lib64/flutter-sfos/3.44.0
exec /usr/share/hello-sfos/hello_sfos --bundle=/usr/share/hello-sfos --fullscreen --onscreen-keyboard --title="Hello SFOS"
