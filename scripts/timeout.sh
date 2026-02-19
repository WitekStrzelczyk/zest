#!/bin/bash

# Simple timeout utility using bash built-ins (no perl needed)
# Usage: ./scripts/timeout.sh <seconds> <command> [args...]
#        source ./scripts/timeout.sh && timeout_func <seconds> <command>

# Function to run a command with timeout (when sourced)
timeout_func() {
    local timeout_seconds=$1
    shift
    local cmd=("$@")
    
    # Run command in background
    "${cmd[@]}" &
    local pid=$!
    
    # Wait for command with timeout
    local count=0
    while kill -0 "$pid" 2>/dev/null; do
        if ((count >= timeout_seconds)); then
            kill -TERM "$pid" 2>/dev/null
            sleep 1
            kill -KILL "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            return 124
        fi
        sleep 1
        ((count++))
    done
    
    wait "$pid"
    return $?
}

# Standalone execution mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <seconds> <command> [args...]"
        echo "Example: $0 30 swift test"
        exit 1
    fi
    
    TIMEOUT_SECONDS=$1
    shift
    
    # Run command with timeout using bash built-ins
    "$@" &
    PID=$!
    
    COUNT=0
    while kill -0 $PID 2>/dev/null; do
        if ((COUNT >= TIMEOUT_SECONDS)); then
            kill -TERM $PID 2>/dev/null
            sleep 1
            kill -KILL $PID 2>/dev/null
            wait $PID 2>/dev/null
            echo "[TIMEOUT] Command exceeded ${TIMEOUT_SECONDS}s limit" >&2
            exit 124
        fi
        sleep 1
        ((COUNT++))
    done
    
    wait $PID
    exit $?
fi
