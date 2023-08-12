

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
-   Allows for multiple configurations in one config file
-   An absolute path, E.g. when the executable is not in your path


# Installing

Head over to the [releases](https://github.com/wreedb/UDLaunch/releases) page and download
the the latest pre-compiled binary. Alternatively, you can build it from source with
the instructions below


# Building

The only dependency needed to build UDLaunch is the [V](https://vlang.io/) compiler.   
Once you have that, you can follow these steps:

    git clone https://github.com/wreed/udlaunch.git; cd udlaunch
    v . -prod # for a release build
    v .       # for a debug build

Once built, you can copy the binary to you `~/.local/bin` directory, or   
anywhere in your `PATH`. Then you can copy the [example configuration file](./example/config.toml)   
into your `~/.config` under a directory called `udlaunch`, or write one   
from scratch using the example as a reference for the syntax.


# Configuring

Each entry in the configuration may the following fields:

-   **name**: the name of program&rsquo;s executable file in quotes
    -   required, actually the only required value.
-   **restart**: true to have the program restarted, false otherwise (no quotes)
    -   optional, defaults to `false`.
-   **args**: arguments to pass to the program, in square brackets, quoted and separated by commas
    -   optional, defaults to `[]` (no arguments).
-   **setenvs**: env variables to set for the program in brackets, quoted, assigned with `=` and separated by commas
    -   optional, defaults to `{}`, (no environment variable setting).
-   **unsetenvs**: env variables to unset for the program, in square brackets, quoted, separated by commas
    -   optional, defaults to `[]` (no environment variable unsetting).
-   **path**: absolute path the executable file
    -   optional, UDLaunch will attempt to find the program in your `PATH`.


# Examples

Here are some examples of the configuration, using [Mako](https://wayland.emersion.fr/mako/), [XFSettingsd](https://gitlab.xfce.org/xfce/xfce4-settings) and [Waybar](https://github.com/alexays/waybar)

```toml
[default]
[default.xfsettingsd]
name = 'xfsettingsd'
args = ['--disable-wm-check', '--daemon']
unsetenvs = ['WAYLAND_DISPLAY']
path = '/usr/bin/xfsettingsd'

[default.mako]
name = 'mako'
restart = true
setenvs = { 'EXAMPLE_ENV_VAR' = '1' }

[default.waybar]
name = 'waybar'
args = ['--log-level=critical']
```

# License and contact information

The included license is the [BSD-2-Clause](./LICENSE) license.
You can contact me by email at [wreedb@skiff.com](mailto:wreedb@skiff.com)

