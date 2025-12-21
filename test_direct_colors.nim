import strutils
# Test if ANSI codes work directly
stdout.write("\e[0m")  # Reset
stdout.write("\e[38;2;255;0;0mThis is RED (255,0,0)\e[0m\n")
stdout.write("\e[38;2;0;255;0mThis is GREEN (0,255,0)\e[0m\n")
stdout.write("\e[38;2;0;0;255mThis is BLUE (0,0,255)\e[0m\n")
stdout.write("\e[38;2;255;255;0mThis is YELLOW (255,255,0)\e[0m\n")
stdout.write("\e[1;38;2;255;0;0mBOLD RED\e[0m\n")
stdout.flushFile()
