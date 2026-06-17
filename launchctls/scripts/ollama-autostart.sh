#!/usr/bin/env bash

# We must preserve stdout for socat's data transfer.
# All logging should go to stderr.

SOCAT_BIN=/Users/szymon/.nix-profile/bin/socat
OLLAMA_PID_FILE="$HOME/Library/Caches/ollama_serve.pid"
TIMER_PID_FILE="$HOME/Library/Caches/ollama_timer.pid"
IDLE_TIMEOUT=600 # 10 minutes

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
}

if [ "$1" = "handler" ]; then
    # 1. Start Ollama if it's not running
    if [ ! -f "$OLLAMA_PID_FILE" ] || ! kill -0 "$(< "$OLLAMA_PID_FILE")" 2>/dev/null; then
        log "Starting ollama serve..."
        OLLAMA_HOST=127.0.0.1:11435 /Users/szymon/.nix-profile/bin/ollama serve > "$HOME/Library/Logs/ollama.log" 2>&1 &
        echo $! > "$OLLAMA_PID_FILE"
        
        # wait for it to be ready
        for i in {1..50}; do
            if nc -z 127.0.0.1 11435 2>/dev/null; then break; fi
            sleep 0.1
        done
    fi

    # 2. Reset the idle timer
    if [ -f "$TIMER_PID_FILE" ]; then
        kill "$(< "$TIMER_PID_FILE")" 2>/dev/null
    fi
    
    (
        if sleep $IDLE_TIMEOUT; then 
            log "10m idle timeout reached. Stopping ollama serve..."
            if [ -f "$OLLAMA_PID_FILE" ]; then
                kill "$(< "$OLLAMA_PID_FILE")" 2>/dev/null
                rm -f "$OLLAMA_PID_FILE"
            fi
        fi
    ) &
    echo $! > "$TIMER_PID_FILE"

    # 3. Pass the connection to ollama
    exec "$SOCAT_BIN" STDIO TCP:127.0.0.1:11435
fi

log "Ollama Proxy listening on 11434..."
exec "$SOCAT_BIN" TCP-LISTEN:11434,reuseaddr,fork EXEC:"$0 handler"
