#!/bin/sh

# REQUIREMENTS:
# python srt module: install with `pip3 install srt`
# custom fork of macOCR: https://github.com/glowinthedark/macOCR
#
# USAGE:
# ./do-all.sh video.mp4

set -e

read -r -p "Generate cropped video $1_video-cropped.mp4? (Y/N).." answer
case ${answer:0:1} in
    y|Y )
        ################### TODO: adjust crop area for input video ##########################
        ffmpeg -i "$1" -filter:v "crop=1738:115:100:965" -c:a copy "$1_video-cropped.mp4"
    ;;
    * )
        echo Skipping...
    ;;
esac

# STEP 2: extract key frames to png images with detection threshold

# generate 1 snapshot per second
read -r -p "Generate snapshots (y/n)?.." answer
case ${answer:0:1} in
    y|Y )
        rm -rfv "$1_img"
        mkdir -p "$1_img"
        ffmpeg -i "$1_video-cropped.mp4" -start_number 1 -vf "fps=1" -q:v 2 "$1_img/snap_%04d.png"
    ;;    
    * )
        echo Skipping...
    ;;
esac

read -r -p "Start OCR (y/n)?.." answer
case ${answer:0:1} in
    y|Y )
        rm -rfv "$1_results.json"
        python3 do-ocr.py "$1_img" "$1_results.json"
    ;;
    * )
        echo Skipping...
    ;;
esac

read -p "Generate SRT (y/n)?.." answer
case ${answer:0:1} in
    y|Y )
        rm "$1.ocr.srt"
        python3 gensrt.py "$1_results.json" "$1.ocr.srt"
    ;;
    * )
        echo Skipping...
    ;;
esac

read -p "SRT normalize and deduplicate inplace (y/n)?.." answer
case ${answer:0:1} in
    y|Y )
      srt-normalise -i "$1.ocr.srt" --inplace --debug
    ;;
    * )
        echo Skipping...
    ;;
esac