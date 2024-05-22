#!/bin/bash

# Check if FFmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: FFmpeg is not installed. Please install FFmpeg and try again."
    exit 1
fi

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 input.mp4 [input2.mp4 input3.mp4 ...]"
    exit 1
fi

# Extract all input MP4 files
input_files=("$@")

# Process each input MP4 file
for input_mp4 in "${input_files[@]}"; do
    # Check if the input MP4 file exists
    if [ ! -f "$input_mp4" ]; then
        echo "Error: Input file '$input_mp4' not found."
        exit 1
    fi

    # Get the directory where the input MP4 file is located
    input_directory=$(dirname "$input_mp4")

    # Convert MP4 to WAV with 16kHz sample rate
    output_wav="${input_directory}/$(basename "$input_mp4" .mp4).wav"
    ffmpeg -i "$input_mp4" -vn -acodec pcm_s16le -ar 16000 "$output_wav"

    # Get the number of audio channels using ffprobe
    num_channels=$(ffprobe -v error -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$output_wav")

    # If the WAV file has three or more audio channels, downmix to mono
    if [ "$num_channels" -ge 3 ]; then
        mono_output_wav="${input_directory}/$(basename "$input_mp4" .mp4)_mono.wav"
        ffmpeg -i "$output_wav" -ac 1 "$mono_output_wav"
        echo "Downmixed $num_channels audio channels to mono. Output saved as $mono_output_wav."
        # Uncomment the line below if you want to keep both the stereo and mono files.
        # echo "Stereo output is also saved as $output_wav."
        rm "$output_wav" # Remove the original stereo file if not needed.
        output_wav="$mono_output_wav"
    else
        echo "The output WAV file has less than three channels. No downmixing needed."
    fi

    # Change the working directory to /Users/swswswsolo/whisper.cpp
    cd /Users/swswswsolo/whisper.cpp

    # Get the file name of the input WAV file without the extension
    file_name=$(basename "$output_wav" .wav)

    # Define the output file path within the input directory
    output_wav="${input_directory}/${file_name}.wav"

    # Execute the 'main' program with the specified arguments for each input file
    # add --max-context 0 after model if lines repeating
    # add WHISPER_COREML=1 before make -j to use ANE
    make clean
    WHISPER_COREML=1 make -j && ./main -m models/ggml-large-v2.bin -l en -otxt -osrt -f "$output_wav"

    # Delete the WAV file after processing
    rm "$output_wav"

done

