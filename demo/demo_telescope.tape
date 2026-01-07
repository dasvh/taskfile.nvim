Output demo_telescope.gif

Set Theme "TokyoNight"

Set Padding 5
Set Margin 10
Set MarginFill "#3D4262"
Set BorderRadius 7

Set Width 1440
Set Height 900
Set FontSize 16

Hide
Type "cd $HOME/git/examples/go-web-app"
Enter
Type "echo $PWD"
Enter
Type "nvim app.go"
Enter

Type ":lua require('taskfile').setup({ picker = 'telescope', layout = 'vertical', windows = { output = { width = 0.8, height = 0.8, }, list = { width = 0.8, height = 0.8, }, })"
Enter

Sleep 500ms
Type ":"
Backspace

Show
Sleep 750ms
Type ":Task"
Sleep 750ms
Enter
Sleep 750ms

Escape
Type ":TaskToggleLayout"
Sleep 500ms
Enter
Sleep 500ms

Type "clean"
Sleep 1000ms
Enter
Sleep 1000ms
Type "q"
Sleep 1000ms


Type ":Task"
Sleep 1000ms
Enter
Sleep 1000ms

Ctrl+n
Sleep 500ms
Ctrl+n
Sleep 500ms
Enter
Sleep 1000ms

Type "q"
Sleep 1000ms

Space
Sleep 1000ms
Type "t"
Sleep 1000ms
Type "r"
Sleep 1000ms
