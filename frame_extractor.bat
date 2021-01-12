@echo off
set working_dir=%~dp0
set video=%~1
if "%video%"=="" (
  echo Usage: Drag a video file onto this batch file.
  pause>nul
  goto :eof
)
set /p name=Video Name (no-spaces): 
set output_folder="%AppData%\framescop\framedata\%name%"
mkdir "%output_folder%"
del "%output_folder%\*"
%working_dir%\ffmpeg.exe -i "%video%" -r 30 -s 320x240 "%output_folder%\%%d.png"
%working_dir%\ffmpeg.exe -r 30 -s 320x240 -i "%output_folder%\%%d.png" -vcodec libx264 -crf 25  -pix_fmt yuv420p -map 0 -segment_time 00:01:00 -f segment -reset_timestamps 1 "%output_folder%\%%d.mp4"
del "%output_folder%\*.png"

echo offsets> "%output_folder%\offsets.txt"
setlocal enableextensions
setlocal enabledelayedexpansion
set count=0
for %%x in ("%output_folder%\*.mp4") do (
  for /f "usebackq" %%i in (`ffprobe -v error -show_entries "stream=nb_frames" -select_streams v:0 -of "default=nokey=1:noprint_wrappers=1" "%output_folder%\!count!.mp4"`) do (
    echo %%i>> "%output_folder%\offsets.txt"
  )
  set /a count+=1
)
endlocal