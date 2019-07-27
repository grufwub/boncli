# boncli BETA

*please note this is still in beta and needs to be tested. please only use this on non-production systems and ensuring that you have backups!*


A user friendly dotfile manager designed for Pengwin WSL (https://github.com/whitewaterfoundry/Pengwin) users, but usable on any 64-bit Linux / MacOS systems. Providing a wrapper script around existing tools written in go, bundled with a friendly curses-based file picker written in python.


To install execute the following, though /usr/local/bin can be replaced with any directory in path should you wish:

`curl -fLo /usr/local/bin/boncli 'https://github.com/grufwub/boncli/raw/master/boncli' && chmod +x /usr/local/bin/boncli`


By default boncli installs the required binaries and sync directory to `$HOME/.boncli`, with binaries under `$BONCLI_ROOT/bin` and user synced files under `$BONCLI_ROOT/sync`. You can change this directory simply by setting the `BONCLI_ROOT` environment variable in your shell.


Based on the hardwork by:

- talal, the author of **bonclay**, a simple dotfile manager written in go (https://github.com/talal/bonclay)

- mikefarah, the author of **yq**, a portable command-line YAML processor written in go (https://github.com/mikefarah/yq)


Roadmap:

- replace the Python file picker with the planned version re-written in C

- flesh out this README further!


Troubleshooting:

- if you use pyenv to manage your python installations, you might run into a '_curses' module not found error. if this is the case, then you need to install the ncurses developer package for you distribution, uninstall that version of python3 through pyenv, then reinstall it so that it can build python3 with the appropriate ncurses modules. if this still doesn't work, then installing python3 through your distribution's package management system should fix it
