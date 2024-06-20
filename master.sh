#!/bin/sh
# USAGE:
# ./do-all.sh -v video.mp4 -c 1738:115:100:965 -f 5 -s "00:02:19" -e "00:22:54"
# If START_TIME or END_TIME not provided, they will be calculated based on video length.

set -e

usage() { echo "Usage: $0 [-v <video>] [-c <crop_zone>] [-f <frames per second>] [-s <start_time>] [-e <end time>]" 1>&2; exit 1; }

while getopts ":v:c:r:s:e:" o; do
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

if [ -z "${video}" ] || [ -z "${crop_zone}" ] || [ -z "${fps}" ]; then
    usage
fi

getVideoDuration() {
    local video=$1
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $video
}

if [ -z "${START_TIME}" ] || [ -z "${END_TIME}" ]; then
    videoDuration=$(getVideoDuration $video)
    
    if [ -z "${START_TIME}" ]; then
        START_TIME="00:02:19" # You can replace this with your own default value or logic to calculate start time. For example, you could subtract 30 seconds from the video duration.
    fi
    
    if [ -z "${END_TIME}" ]; then
        END_TIME="00:22:54" # You can replace this with your own default value or logic to calculate end time. For example, you could subtract 10 seconds from the video duration.
    fi
fi

start_timestamp=$(date -u -d "$START_TIME" +%s)
end_timestamp=$(date -u -d "$END_TIME" +%s)
timediff=$(( end_timestamp - start_timestamp ))
etime=$(date -u -d "@${timediff}" +"%H:%M:%S")

# STEP 1: crop the video
ffmpeg -i "${video}" -filter:v "crop=${crop_zone}" -c:a copy "${video}_video-cropped.mp4"

# STEP 2: extract key frames to png images with detection threshold
mkdir -p "${video}_img"
ffmpeg -i "${video}_video-cropped.mp4" -to "$etime" -vf "fps=${fps}" -q:v 2 "${video}_img/snap_%04d.png"

# STEP 3: run OCR on the images
python3 do-ocr.py "${video}_img" "${video}_results.json"

# STEP 4: generate SRT file from OCR results
python3 gen-srt.py "${video}_results.json" "${video}.ocr.srt"

# STEP 5: normalize and deduplicate the SRT in-place
srt-normalise -i "${video}.ocr.srt" --inplace --debug


ffs "${video}" -i "${video}.ocr.srt" -o "${video}.srt"