from difflib import SequenceMatcher
import json
import sys
from pathlib import Path

import srt

def generate_srt(json_input_file=None):
    with open(json_input_file, "r") as f:
        ocr_dict = json.load(f)

    subtitles = []
    start_time = datetime.timedelta()
    sorted_int_keys = sorted([int(k) for k in ocr_dict.keys()])
    current_subtitle: srt.Subtitle = None
    
    # Define a threshold for similar texts
    SIMILARITY_THRESHOLD = 0.8 

    for frame_number in sorted(ocr_dict.keys()):
        body = ocr_dict.get(str(frame_number)).strip()

        if body:
            start_time = datetime.timedelta(seconds=int(frame_number))
            end_time = start_time + datetime.timedelta(milliseconds=1000)

            subtitle = srt.Subtitle(None, start_time, end_time, body)
            
            if not current_subtitle:
                current_subtitle = subtitle
                continue
                
            # Check similarity between current and previous subtitles
            similarities = SequenceMatcher(None, current_subtitle.content, body).ratio()

            if similarities >= SIMILARITY_THRESHOLD:
                current_subtitle.end = current_subtitle.end + datetime.timedelta(milliseconds=1000)
            else:
                subtitles.append(current_subtitle)
                print(current_subtitle.to_srt())
                current_subtitle = subtitle
        else:
            if current_subtitle:
                subtitles.append(current_subtitle)
                print(current_subtitle.to_srt())
                current_subtitle = None
                
    return subtitles

json_input = sys.argv[1]
srt_output = sys.argv[2]

subtitles = generate_srt(json_input_file=json_input)
Path(srt_output).write_text(srt.compose(subtitles), encoding='utf-8')