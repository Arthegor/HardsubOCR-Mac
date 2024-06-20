#!/bin/bash
# USAGE:
# ./master.sh -v video.mp4 -c "1738:115:100:965" -f 5 -s "00:02:19" -e "00:22:54"

set -e

usage() { echo "Usage: $0 [-v <video>] [-c <crop_zone>] [-f <frames per second>] [-s <start_time>] [-e <end time>]" 1>&2; exit 1; }

while getopts ":v:c:f:s:e:" o; do
    case "${o}" in
        v)
            video=${OPTARG}
                ;;
        c)
            crop_zone=${OPTARG}
                ;;
        f)
            fps=${OPTARG}
                ;;
        s)
            START_TIME=${OPTARG}
                 ;;
        e)
            END_TIME=${OPTARG}
                  ;;
          *)
            usage
                ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${video}" ] || [ -z "${crop_zone}" ] || [ -z "${fps}" ] || [ -z "${START_TIME}" ] || [ -z "${END_TIME}" ]; then
    usage
fi

# start_timestamp=$(date -u -d "$START_TIME" +%s)
# end_timestamp=$(date -u -d "$END_TIME" +%s)
# timediff=$(( end_timestamp - start_timestamp ))
# etime=$(date -u -d @${timediff} +%H:%M:%S)

# convert start and end times to seconds
start_timestamp=$(echo ${START_TIME} | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
end_timestamp=$(echo ${END_TIME} | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
timediff=$(( end_timestamp - start_timestamp ))

# calculate the duration in HH:MM:SS format
etime_hours=$(( timediff / 3600 ))
timediff=$(( timediff % 3600 ))
etime_minutes=$(( timediff / 60 ))
timediff=$(( timediff % 60 ))
etime="${etime_hours}:${etime_minutes}:${timediff}"

# STEP 1: crop the video
ffmpeg -i "${video}" -filter:v "crop=${crop_zone}" -c:a copy "${video}_video-cropped.mp4"

# STEP 2: extract key frames to png images with detection threshold
mkdir -p "${video}_img"
ffmpeg -i "${video}_video-cropped.mp4" -to "$etime" -vf fps="${fps}" -q:v 2 "${video}_img/snap_%04d.png"

# STEP 3: run OCR on the images
python3 do-ocr.py "${video}_img" "${video}_results.json"

# STEP 4: generate SRT file from OCR results
python3 gen-srt.py "${video}_results.json" "${video}.ocr.srt"

# STEP 5: normalize and deduplicate the SRT in-place
srt-normalise -i "${video}.ocr.srt" --inplace --debug

ffsubsync "${video}" -i "${video}.ocr.srt" -o "${video}.srt"