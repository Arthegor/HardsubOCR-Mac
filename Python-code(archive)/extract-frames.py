import ffmpeg
from pathlib import Path

# Define input and output paths
input_path = 'input.mp4'
output_folder = Path('output_frames')
output_folder.mkdir(exist_ok=True)

# Extract frames with timestamps in filenames
stream = (
    ffmpeg
    .input(str(input_path))
    .filter('select', 'eq(mod(n,5),0)')  # Select every 5th frame
    .output(f'{output_folder}/%04d_%09d.png', vframes=1)  # Output with frame number and timestamp
)

# Run the command
ffmpeg.run(stream)