# Media Player controls for Lua with Mpris and DBus

Use the DBus
[Media Player Remote Interfacing Specification (Mpris)](https://specifications.freedesktop.org/mpris-spec/2.2/)
to control your media player (e.g.[ VLC](https://www.videolan.org/),
[QuodLibet](https://quodlibet.readthedocs.io/)).

# Requirements

In addition to the requirements listed in the `rockspec` file, you will need
the [Awesome Window Manager](https://awesomewm.org) and DBus.

You will also need the DBus headers (`dbus.h`) installed.
For example, Debian and Ubuntu provide the DBus headers with the `libdbus-1-dev`
package, Fedora, RedHad and CentOS provide them with the `dbus-devel` package,
while Arch provides them (alongside the binaries) with the `libdbus` package.

# Installation

## Using Luarocks

Probably, the easiest way to install this widget is to use `luarocks`:

    luarocks install media_player

You can use the `--local` option if you don't want or can't install
it system-wide

This will ensure that all its dependencies are installed.

### A note about ldbus

This module depends on the [`ldbus`](https://github.com/daurnimator/ldbus)
module that provides the low-level DBus bindings

    luarocks install --server=http://luarocks.org/manifests/daurnimator \
        ldbus \
        DBUS_INCDIR=/usr/include/dbus-1.0/ \
        DBUS_ARCH_INCDIR=/usr/lib/dbus-1.0/include

As usual, you can use the `--local` option if you don't want or can't install
it system-wide.

# Usage

Require the `media_player` module and then create a media player interface
for each player that implements the Mpris specification.

When creating a media player with a given `NAME`, the module will
attempt to connect to a DBus destination called `org.mpris.MediaPlayer2.<NAME>`.

A media player is created with

    local media_player = require("media_player")
    player = media_player.MediaPlayer:new(name)

You can then use the `play`, `stop`, `previous` and `next` methods to control
the player.

The `position` and `position_as_str` methods return the position of the track
in microseconds and as `HH:MM:SS` respectively.

The `metadata` method returns the current track's metadata in a table as per the
[metadata specification](https://www.freedesktop.org/wiki/Specifications/mpris-spec/metadata/).

The `info` method returns a subset of the metadata in a table with the following
keys:

* `album`: name of the album
* `title`: title of the song
* `year`: song year
* `artists`: comma-separated list of artists (may be just one artist)
* `length`: total lenght of the track as `HH:MM:SS`

See the generated documentation for more detailed information.

## An example using the Awesome Window Manager

Require the `media_player` module in your Awesome configuration file
`~/.config/awesome/rc.lua` and then create a media player interface
for each player that implements the Mpris specification.

You can create as many players as you want and bind them to different keys.

If you want to display information about the current track, you can use the
`metadata` or `info` methods to extract it and then use it e.g. with Awesome's
[`naughty.notify`](https://awesomewm.org/doc/api/modules/naughty.html#notify).

For example:

    local media_player = require("media_player")
    local quodlibet = media_player.MediaPlayer:new("quodlibet")
    local vlc =  media_player.MediaPlayer:new("vlc")

Then you can bind the keys:

    awful.util.table.join(
      -- QuodLibet bound to the media keys
      awful.key({}, "XF86AudioPlay", function () quodlibet:play() end),
      awful.key({}, "XF86AudioStop", function () quodlibet:stop() end),
      awful.key({}, "XF86AudioPrev", function () quodlibet:previous() end),
      awful.key({}, "XF86AudioNext", function () quodlibet:next() end),
      -- modkey + i shows useful information from QuodLibet
      awful.key({modkey}, "i", function ()
          local info = quodlibet:info()
          naughty.notify({title=info.title, text=info.album})
      end)
      -- VLC bound to modkey + media keys
      awful.key({modkey}, "XF86AudioPlay", function () vlc:play() end),
      awful.key({modkey}, "XF86AudioStop", function () vlc:stop() end),
      awful.key({modkey}, "XF86AudioPrev", function () vlc:previous() end),
      awful.key({modkey}, "XF86AudioNext", function () vlc:next() end)
    )

Since Awesome calls the functions without passing the object as first parameter,
we must wrap the call to the object's methods in an anonymous function.

# Documentation

The documentation can be generated using [LDoc](http://stevedonovan.github.io/ldoc/).
Running `ldoc .` in the root of the repository will generate HTML documentation
in the `doc` directory.
