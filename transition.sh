
swaybg --image stitch_wall.png --mode stretch &
sleep 2

niri msg action do-screen-transition
pkill swaybg
swaybg --image stitch_wall_dark.png --mode stretch &

sleep 5
pkill swaybg
