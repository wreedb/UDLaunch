

# What is UDLaunch?

UDLaunch is a tool for launching multiple programs from a single command   
with settings you define in a configuration file (which is in [TOML](https://toml.io/en/) format).   


## What is it good for?

It is great for launching user-level [daemons](https://en.wikipedia.org/wiki/Daemon_(computing)) when you log in to your computer   
Some examples could be a program that sets your wallpaper, a status bar, a   
desktop notification daemon, a polkit service or a session manager, but it   
can run whatever you need it to.


## Features of UDLaunch

UDLaunch allows you to configure:

-   The arguments you&rsquo;d like to append the command when it&rsquo;s run
-   Whether or not the daemon should be killed/restarted when UDLaunch is run
-   Any environment variable(s) that need to be set *or unset* for your program to run properly

Planned features:

-   Allow for multiple configurations in the configuration file


# Building

The only dependency needed to build UDLaunch is the [V](https://vlang.io/) compiler.   
Once you have that, you can follow these steps:
```shell
git clone https://codeberg.org/wreed/udlaunch.git; cd udlaunch
v . -prod # for a release build
v .       # for a debug build
```
Once built, you can copy the binary to you `~/.local/bin` directory, or   
anywhere in your `PATH`. Then you can copy the [example configuration file](./example/config.toml)   
into your `~/.config` under a directory called `udlaunch`, or write one   
from scratch using the example as a reference for the syntax.


# Configuring

Each entry in the configuration must have the following fields:

-   **name**: the name of programs executable file (in quotes)
-   **restart**: true to have the program restarted, false otherwise (no quotes)
-   **args**: arguments to pass to the program, in square brackets, quoted and separated by commas
-   **setenvs**: env variables to set for the program in brackets, quoted, assigned with `=` and separated by commas
-   **unsetenvs**: env variables to unset for the program, in square brackets, quoted, separated by commas


NOTE: For entries such as `setenvs`, `unsetenvs`, and `args`: if they are   
not needed, set their value as an empty set of square `[]` or regular `{}`   
brackets respectively.


# Examples

Here are some examples of the configuration, using [Mako](https://wayland.emersion.fr/mako/), [Xfsettingsd](https://gitlab.xfce.org/xfce/xfce4-settings) and [Waybar](https://github.com/alexays/waybar)
```toml
[xfsettingsd]
name = 'xfsettingsd'
restart = false
args = ['--disable-wm-check', '--daemon']
setenvs = {}
unsetenvs = ['WAYLAND_DISPLAY']

[mako]
name = 'mako'
restart = false
args = []
setenvs = { 'EXAMPLE_ENV_VAR' = '1' }
unsetenvs = []

[waybar]
name = 'waybar'
restart = false
args = ['--log-level=critical']
setenvs = {}
unsetenvs = []
```
# License and contact information

The included license is the [BSD-2-Clause](./LICENSE) license.
You can contact me by email at [wreedb@skiff.com](mailto:wreedb@skiff.com)