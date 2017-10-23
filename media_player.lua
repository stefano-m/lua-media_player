--[[
  Copyright 2017 Stefano Mazzucco

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]

--[[-- Create proxy objects that implement the
  [`org.mpris.MediaPlayer2`](https://specifications.freedesktop.org/mpris-spec/latest/)
  DBus interface.  The proxy object exposes all the methods an properties of
  the interface in addition to the methods documented here.  Note that some
  applications may not implement the full MPRIS specification.

  This library is implemented on top of the [`dbus_proxy`](https://github.com/stefano-m/lua-dbus_proxy) module.

  A `dbus_proxy.Proxy` object **cannot** be created unless the media player
  application is running.  The MediaPlayer object implemented here works around
  this limitation by intelligently polling the application and, if does not
  find it, silently ignoring it.

  @license Apache License, version 2.0
  @author Stefano Mazzucco <stefano AT curso DOT re>
  @copyright 2017 Stefano Mazzucco

  @usage
  MediaPlayer = require("media_player")
  vlc = MediaPlayer:new("vlc")
  vlc:PlayPause()
  for k, v in pairs(vlc:info()) do
    print(k, v)
  end
  vlc:Stop()

]]
local string = string
local table = table

local proxy = require("dbus_proxy")

local function time_from_useconds(useconds)
    local s, m, h
    m, s = math.modf(useconds / 60e6)
    s = math.floor(s * 60)
    h, m = math.modf(m / 60)
    m = math.floor(m * 60)
    return h, m, s
end

local function time_from_useconds_as_str(useconds)
  local h, m, s = time_from_useconds(useconds)
  return string.format("%02d:%02d:%02d", h, m, s)
end

--- Get the year from an [Mpris date](https://www.freedesktop.org/wiki/Specifications/mpris-spec/metadata/#index2h3).
-- @tparam string date an Mpris date.
-- @return the year as a string
-- @return `nil` if the date is invalid
local function get_year(date)
  if date then
    return date:match("^[0-9][0-9][0-9][0-9]")
  end
  return nil
end


--- @type MediaPlayer
local MediaPlayer = {}

--- Get the value of a property. You should not need to use this
-- method directly. Instead, you should access the property with the dot
-- notation: e.g. `player.PropertyName`.
--
-- @tparam string property_name the name of a property
-- @return the value of the property
--
-- @return nil if the property is not present or the application is not
-- available
function MediaPlayer:Get(property_name)
  if self.is_connected then
    return self.proxy:Get(self.interface, property_name)
  else
    return nil
  end
end

--- Return the position of the track as a string of the type
-- `HH:MM:SS`.
-- @return a string of the type `HH:MM:SS`
-- @return an empty string if the application is not available
function MediaPlayer:position_as_str()
  if self.is_connected then
    return time_from_useconds_as_str(self.Position)
  else
    return ""
  end
end

--- Return useful information about the track.
-- For full control over the metadata, use `player.Metadata`.
--
-- @return a table with the following keys
-- (if available in the track's metadata):
--
-- - `album`: name of the album
-- - `title`: title of the song
-- - `year`: song year
-- - `artists`: comma-separated list of artists
-- - `length`: total lenght of the track as `HH:MM:SS`
--
-- @return an empty table if the application is not available
--
function MediaPlayer:info()

  if not self.is_connected then
    return {}
  end

  local metadata = self.Metadata

  local info = {
    album = metadata["xesam:album"],
    title = metadata["xesam:title"],
    year = get_year(metadata["xesam:contentCreated"])
  }

  local artists = metadata["xesam:artist"]
  if type(artists) == "table" then
    artists = table.concat(artists, ", ")
  end
  info.artists = artists

  local length = metadata["mpris:length"]
  if type(length) == "number" then
    length = time_from_useconds_as_str(length)
  end
  info.length = length

  return info
end

--[[-- Create a new MediaPlayer proxy object

  @tparam string name name of the application as found in the unique bus name:
  `org.mpris.MediaPlayer2.<name>`. E.g. `org.mpris.MediaPlayer2.vlc`. The
  resulting DBus name will also be exposed as a field of the object
  (i.e. `player.name`)

]]
function MediaPlayer:new(name)
  local opts = {
    bus = proxy.Bus.SESSION,
    name = "org.mpris.MediaPlayer2." .. name,
    interface = "org.mpris.MediaPlayer2.Player",
    path = "/org/mpris/MediaPlayer2"
  }
  local o = proxy.monitored.new(opts)
  o.position_as_str = self.position_as_str
  o.info = self.info
  o.Get = self.Get
  return o
end

return MediaPlayer
