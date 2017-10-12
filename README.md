# Media Player controls for Lua with Mpris and DBus

Use the DBus
[Media Player Remote Interfacing Specification (Mpris)](https://specifications.freedesktop.org/mpris-spec/latest/)
to control your media player (e.g.[ VLC](https://www.videolan.org/),
[QuodLibet](https://quodlibet.readthedocs.io/)).

# Installation

## Using Luarocks

Probably, the easiest way to install this widget is to use `luarocks`:

    luarocks install media_player

You can use the `--local` option if you don't want or can't install
it system-wide

This will ensure that all its dependencies are installed.


# Usage

Require the `media_player` module and then create a media player interface
for each player that implements the Mpris specification.

When creating a media player with a given `NAME`, the module will
attempt to connect to a DBus destination called `org.mpris.MediaPlayer2.<NAME>`.

A media player is created with

```lua
MediaPlayer = require("media_player")
player = MediaPlayer:new(name)
```

You can then , for example, use the `PlayPause`, `Stop`, `Previous` and `Next`
methods to control the player.

For more detail, see also the
[dbus_proxy](https://github.com/stefano-m/lua-dbus_proxy/) documentation.

The `Position` property and `position_as_str` method return the position of the
track in microseconds and as `HH:MM:SS` respectively.

The `Metadata` property returns the current track's metadata in a table as per
the
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
`~/.config/awesome/rc.lua` and then create a media player interface for each
player that implements the Mpris specification.

You can create as many players as you want and bind them to different keys.

If you want to display information about the current track, you can use
`Metadata` or `info` to extract it and then use it e.g. with
Awesome's
[`naughty.notify`](https://awesomewm.org/doc/api/modules/naughty.html#notify).

For example:

```lua
MediaPlayer = require("media_player")
quodlibet = MediaPlayer:new("quodlibet")
vlc = MediaPlayer:new("vlc")
```

Then you can bind the keys.  In this example, the basic controls are set up,
plus a notification and bindings to quit the application.

```lua
awful.util.table.join(
  -- QuodLibet bound to the media keys
  awful.key({}, "XF86AudioPlay", function () quodlibet:PlayPause() end),
  awful.key({}, "XF86AudioStop", function () quodlibet:Stop() end),
  awful.key({"Control"}, "XF86AudioStop", function () quodlibet:Quit() end),
  awful.key({}, "XF86AudioPrev", function () quodlibet:Previous() end),
  awful.key({}, "XF86AudioNext", function () quodlibet:Next() end),
  -- modkey + i shows useful information from QuodLibet
  awful.key({modkey}, "i", function ()
      local info = quodlibet:info()
      naughty.notify({title=info.title, text=info.album})
  end)
  -- VLC bound to modkey + media keys
  awful.key({modkey}, "XF86AudioPlay", function () vlc:PlayPause() end),
  awful.key({modkey}, "XF86AudioStop", function () vlc:Stop() end),
  awful.key({"Shift", "Control"}, "XF86AudioStop", function () vlc:Quit() end),
  awful.key({modkey}, "XF86AudioPrev", function () vlc:Previous() end),
  awful.key({modkey}, "XF86AudioNext", function () vlc:Next() end)
)
```

Since Awesome calls the functions without passing the object as first parameter,
we must wrap the call to the object's methods in an anonymous function.

# Documentation

The documentation can be generated using [LDoc](http://stevedonovan.github.io/ldoc/).
Running `ldoc .` in the root of the repository will generate HTML documentation
in the `docs` directory.
