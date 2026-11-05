Source common.tape
Output scratch.gif
Set Height 1300
Hide
Type ". ./setup.sh"
Enter
Sleep 1s
Show
Sleep 800ms
Type "yakitsuke --dry-run --format svcd holiday.mp4 holiday.srt"
Enter
Sleep 8s
Screenshot dry-run.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "yakitsuke wedding.mov"
Enter
Sleep 3s
Screenshot error.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "yakitsuke doctor"
Enter
Sleep 10s
Screenshot doctor.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "for t in kodougu catppuccin-mocha dracula nord gruvbox tokyo-night; do yakitsuke --theme $t version; done"
Enter
Sleep 8s
Screenshot themes.png
Sleep 1s
Sleep 1s
