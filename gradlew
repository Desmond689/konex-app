#!/usr/bin/env sh
# Gradle wrapper script (minimal placeholder)
# Note: For full Gradle wrapper functionality include gradle/wrapper/gradle-wrapper.jar.
# This script will try to invoke an installed gradle if available.
if [ -z "$GRADLE_HOME" ]; then
  gradle "$@"
else
  "$GRADLE_HOME/bin/gradle" "$@"
fi
