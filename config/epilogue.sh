#!/bin/bash
JOB_ID=$1

if [ -z "$JOB_ID" ]; then
    echo "Usage: $0 <job_id>"
    exit 1
fi

# Check if job is running
sleep 1
KNOWN_STATES="RUNNING PENDING COMPLETED FAILED CANCELLED TIMEOUT PREEMPTED SUSPENDED NODE_FAIL OUT_OF_MEMORY CONFIGURING COMPLETING RESIZING REQUEUED REQUEUING SPECIAL_EXIT BOOT_FAIL DEAD NODE_FAIL SIGNALING STAGE_OUT STOPPED SUSPENDED SYSTEM FAILURE"
while true; do
    STATE=$(sacct -j "$JOB_ID" --format=State --noheader | awk 'NR==1{print $1}')
    if [ "$STATE" = "RUNNING" ]; then
        echo "Job $JOB_ID is RUNNING."
        break
    elif [ "$STATE" = "PENDING" ]; then
        echo "Job $JOB_ID is PENDING. Checking again in 30 seconds..."
        sleep 30
    elif echo "$KNOWN_STATES" | grep -qw "$STATE"; then
        echo "Job $JOB_ID is in state: $STATE. Exiting with error."
        exit 2
    else
        echo "Job $JOB_ID is in unknown state: $STATE. Checking again in 5 seconds..."
        sleep 5
    fi
done

# Print job status and check state
while true; do
    STATES=($(sacct -j "$JOB_ID" --format=State --noheader | awk '{print $1}'))
    ANY_RUNNING=false
    ALL_COMPLETED=true
    for STATE in "${STATES[@]}"; do
        if [ "$STATE" = "RUNNING" ]; then
            ANY_RUNNING=true
        fi
        if [ "$STATE" != "COMPLETED" ]; then
            ALL_COMPLETED=false
        fi
    done

    if [ "$ANY_RUNNING" = true ]; then
        # At least one job is running
        for f in logs/${JOB_ID}_*.out; do
            if [ -f "$f" ]; then
                LAST_LINE=$(tail -n 1 "$f")
                echo "$(basename "$f"): $LAST_LINE"
            fi
        done
        sleep 30
    elif [ "$ALL_COMPLETED" = true ]; then
        # All jobs are completed
        echo "Job $JOB_ID is completed."
        break
    else
        # Some jobs are in other states
        echo "Job $JOB_ID is in states: ${STATES[*]}. Exiting with error."
        exit 2
    fi
done

rm -f logs/${JOB_ID}_*.out