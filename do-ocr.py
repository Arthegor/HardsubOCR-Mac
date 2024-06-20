#!/usr/bin/env python3
from pathlib import Path
import subprocess
import json
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

def ocr_file(image):
    bucket_key = image.stem.replace("snap_", '')
    
    try:
        # check if the file name is already in the dictionary, and skip it if so
        with lock:
            if bucket_key in ocr_dict:
                return
        
        # run the ocr command on the file, and capture the output from stdout
        proc = subprocess.run(["/usr/local/bin/OCR", "fr", "false", "true", image.absolute()],
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
        
        recognized_text = proc.stdout.decode()
        err = proc.stderr.decode()

        if err:
            print("Erreur", err)
        else:
            with lock:
                print(bucket_key, recognized_text)
                ocr_dict[bucket_key] = recognized_text
                
    except Exception as e:  # catch any exception that might occur during execution
        print("Une erreur est apparu: ", str(e))
        
if __name__ == '__main__':
    lock = threading.Lock()
    
    folder_name = sys.argv[1]
    results_file = sys.argv[2]

    # load the existing dictionary from json file, or create an empty one
    res_file = Path(results_file)
    if res_file.exists():
        with open(res_file, 'r', encoding='utf-8') as f:
            ocr_dict = json.load(f)
    else:
        ocr_dict = {}
    
    # Tweak the threadpool size according to your system's resources
    with ThreadPoolExecutor(max_workers=5) as executor:  # for a 8GB RAM machine, limiting workers to 5 should be fine
        img_path: Path
        for img_path in Path(folder_name).glob("*.png"):
            executor.submit(ocr_file, img_path)
    
    # Write the results back into json file after all threads are done
    with open(results_file, 'w', encoding='utf-8') as f:
        json.dump(ocr_dict, f, ensure_ascii=False, indent=1)