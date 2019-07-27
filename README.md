# boncli

A user friendly dotfile manager. Providing a wrapper script around existing tools written in go, bundled with a friendly curses-based file picker written in python.


To install:

`curl -fLo /usr/local/bin/boncli 'https://github.com/grufwub/boncli/raw/master/boncli'`


By default boncli installs the required binaries and sync directory to `$HOME/.boncli`, with binaries under `$BONCLI_ROOT/bin` and user synced files under `$BONCLI_ROOT/sync`. You can change this directory simply by setting the `BONCLI_ROOT` environment variable in your shell.


Based on the hardwork by: 

- talal, the author of **bonclay**, a simple dotfile manager written in go (https://github.com/talal/bonclay)

- mikefarah, the author of **yq**, a portable command-line YAML processor written in go (https://github.com/mikefarah/yq)


Roadmap:

- replace the Python file picker with the planned version re-written in C
