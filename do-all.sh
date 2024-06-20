#!/bin/sh
# USAGE:
# ./do-all.sh video.mp4 --crop 1738:115:100:965 --fps 5

set -e

usage() { echo "Usage: $0 [-v <video>] [-c <crop_zone>] [-r <frames per second>]" 1>&2; exit 1; }

while getopts ":v:c:r:" o; do
    case "${o}" in
        v)
            video=${OPTARG}
            ;;
        c)
            crop_zone=${OPTARG}
            ;;
        r)
            fps=${OPTARG}
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

# STEP 1: crop the video
ffmpeg -i "${video}" -filter:v "crop=${crop_zone}" -c:a copy "${video}_video-cropped.mp4"

# STEP 2: extract key frames to png images with detection threshold
mkdir -p "${video}_img"
ffmpeg -i "${video}_video-cropped.mp4" -start_number 1 -vf "fps=${fps}" -q:v 2 "${video}_img/snap_%04d.png"
    
# STEP 3: run OCR on the images
python3 do-ocr.py "${video}_img" "${video}_results.json"

# STEP 4: generate SRT file from OCR results
python3 gensrt.py "${video}_results.json" "${video}.ocr.srt"

# STEP 5: normalize and deduplicate the SRT in-place
srt-normalise -i "${video}.ocr.srt" --inplace --debug