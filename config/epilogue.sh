#!/bin/bash
JOB_ID=$1

if [ -z "$JOB_ID" ]; then
    echo "Usage: $0 <job_id>"
    exit 1
fi
# a failed sbatch leaves its error text here instead of an id: don't poll squeue forever
if ! [[ "$JOB_ID" =~ ^[0-9]+$ ]]; then
    echo "Submission failed (no job id): $JOB_ID"
    exit 2
fi

# Check if job is running
sleep 1
KNOWN_STATES="RUNNING PENDING COMPLETED FAILED CANCELLED TIMEOUT PREEMPTED SUSPENDED NODE_FAIL OUT_OF_MEMORY CONFIGURING COMPLETING RESIZING REQUEUED REQUEUING SPECIAL_EXIT BOOT_FAIL DEAD NODE_FAIL SIGNALING STAGE_OUT STOPPED SUSPENDED SYSTEM FAILURE"
MISSING=0
while true; do
    STATE=$(squeue -j "$JOB_ID" -h -o "%T" 2>/dev/null | awk 'NR==1{print $1}')
    REASON=$(squeue -j "$JOB_ID" -h -o "%r" 2>/dev/null)
    if [ -z "$STATE" ]; then
        # not in the queue: either not listed yet (just submitted) or already finished
        MISSING=$((MISSING + 1))
        if [ $MISSING -ge 3 ]; then
            echo "Job $JOB_ID is no longer in the queue (finished). Last log lines:"
            for f in logs/${JOB_ID}_*.out; do [ -f "$f" ] && echo "== $f" && tail -n 5 "$f"; done
            exit 0
        fi
        sleep 5
    elif [ "$STATE" = "RUNNING" ]; then
        echo "Job $JOB_ID is RUNNING."
        break
    elif [ "$STATE" = "PENDING" ]; then
        echo "Job $JOB_ID is PENDING. REASON: $REASON . Checking again in 30 seconds..."
        sleep 30
    elif [ -n "$STATE" ] && echo "$KNOWN_STATES" | grep -Eq "$(echo $STATE | sed 's/ /|/g')"; then
        echo "Job $JOB_ID is in state: $STATE. Exiting with error."
        exit 2
    else
        echo "Job $JOB_ID is in unknown state: $STATE. Checking again in 5 seconds..."
        sleep 5
    fi
done

# Print job status and check state
while true; do
    STATES=($(squeue -j "$JOB_ID" -h -o "%T" | awk '{print $1}'))
    ALL_COMPLETED=true
    ALL_VALID=true
    for STATE in "${STATES[@]}"; do
        if [ "$STATE" != "COMPLETED" ]; then
            ALL_COMPLETED=false
        fi
        if [ "$STATE" != "RUNNING" ] && [ "$STATE" != "PENDING" ] && [ "$STATE" != "COMPLETED" ]; then
            ALL_VALID=false
        fi
    done

    if [ "$ALL_COMPLETED" = true ]; then
        echo "Job $JOB_ID is completed."
        break
    elif [ "$ALL_VALID" = true ]; then
        # All jobs are in RUNNING, PENDING, or COMPLETED
        for f in logs/${JOB_ID}_*.out; do
            if [ -f "$f" ]; then
                LAST_LINE=$(tail -n 1 "$f")
                echo "$(basename "$f"): $LAST_LINE"
            fi
        done
        sleep 30
    else
        # Some jobs are in invalid states
        REASONS=($(squeue -j "$JOB_ID" -h -o "%r"))
        MSG="Job $JOB_ID is in state(s):"
        for i in "${!STATES[@]}"; do
            STATE="${STATES[$i]}"
            REASON="${REASONS[$i]}"
            MSG+=" $STATE (REASON: $REASON)"
        done
        MSG+=". Exiting with error."
        echo "$MSG"
        exit 2
    fi
done

#rm -f logs/${JOB_ID}_*.out