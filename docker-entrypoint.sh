#!/bin/bash
set -e

# Remove server.pid if it exists
if [ -f tmp/pids/server.pid ]; then
  echo "Removing stale server.pid..."
  rm -f tmp/pids/server.pid
fi

# Execute the main command
exec "$@"
