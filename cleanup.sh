#!/bin/bash

CHECK_INTERVAL=2

check_and_cleanup() {
    for pid in $(pgrep -f "tt\+\+"); do
        # Get real-time CPU usage using `top` in batch mode
        cpu_usage=$(top -b -n 2 -d 0.5 -p $pid | awk '/%CPU/ { getline; print $9 }' | tail -1 | awk '{print int($1)}')

        # Terminate immediately if CPU usage is over 90%
        if [ "$cpu_usage" -gt 90 ]; then
            process_name=$(ps -p $pid -o comm=)
            echo "$(date): Extreme CPU usage detected for $process_name process with PID $pid (CPU: $cpu_usage%). Terminating immediately." | tee -a /app/logs/cleanup.log
            kill -9 "$pid"
            continue
        fi

        # If CPU usage is above 20%, wait and check again
        if [ "$cpu_usage" -gt 20 ]; then
            sleep $CHECK_INTERVAL

            # Second CPU check with real-time `top`
            cpu_usage_again=$(top -b -n 2 -d 0.5 -p $pid | awk '/%CPU/ { getline; print $9 }' | tail -1 | awk '{print int($1)}')
            
            # If CPU usage is still above 20%, terminate the process
            if [ "$cpu_usage_again" -gt 20 ]; then
                process_name=$(ps -p $pid -o comm=)
                echo "$(date): High CPU usage detected for $process_name process with PID $pid (CPU: $cpu_usage_again%). Terminating process." | tee -a /app/logs/cleanup.log
                kill -9 "$pid"
            fi
        fi
    done
}

# Run the check in an infinite loop
while true; do
    check_and_cleanup
    sleep $CHECK_INTERVAL
done

