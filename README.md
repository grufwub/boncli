# boncli

A user friendly dotfile manager providing a wrapper script around existing tools written in go, and a friendly ncurses file picker written in python.


To install:

`curl -fLo /usr/local/bin/boncli 'https://github.com/grufwub/boncli/raw/master/boncli'`


By default boncli installs the required binaries and synchronization directory to `$HOME/.boncli`, with binaries under `$BONCLI_ROOT/bin` and user sync'd files under `$BONCLI_ROOT/sync`. But you can change this directory simply by setting the `BONCLI_ROOT` environment variable in your shell.


Based on the hardwork by: 

- talal with bonclay, a simple dotfile manager written in go (https://github.com/talal/bonclay)

- mikefarah with yq, a portable command-line YAML processor written in go (https://github.com/mikefarah/yq)
