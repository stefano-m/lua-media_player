--[[
  Copyright 2016 Stefano Mazzucco <stefano AT curso DOT re>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[--
  @license GNU GPL, version 3 or later
  @author Stefano Mazzucco <stefano AT curso DOT re>
  @copyright 2016 Stefano Mazzucco
]]

local ldbus = require("ldbus_api")

local media_player = {}

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

local function media_player_dbus_property(tbl, name)
  local opts = {
    bus = "session",
    dest = "org.mpris.MediaPlayer2." .. tbl.name,
    interface = "org.freedesktop.DBus.Properties",
    method = "Get",
    path = "/org/mpris/MediaPlayer2",
    args = {
      {sig = "s", value = "org.mpris.MediaPlayer2.Player"},
      {sig = "s", value = name}
    }
  }
  local dbus_data = ldbus.api.call(opts)
  assert(#dbus_data == 1, "Dbus property should be 1 element, got " .. #dbus_data)
  return ldbus.api.get_value(dbus_data[1])
end

local function media_player_dbus(tbl, method, args)
  local t = {}
  for k, v in pairs(tbl.dbus_opts) do
    t[k] = v
  end
  t.method = method
  t.args = args
  return t
end

--- Get the year from an [Mpris date](https://www.freedesktop.org/wiki/Specifications/mpris-spec/metadata/#index2h3).
-- @param date String representing an Mpris date.
-- @return The year as a string or nil.
function media_player.get_year(date)
  if date then
    return date:match("^[0-9][0-9][0-9][0-9]")
  end
  return nil
end

media_player.MediaPlayer = {}

--- Create a new MediaPlayer object that implements the
-- org.mpris.MediaPlayer2.Player DBus interface.
-- @param name The name of the player
-- The DBus well-known name org.mpris.MediaPlayer2.Player.`name`
-- **must** exist for the object to work.
function media_player.MediaPlayer:new(name)
  local t = {}

  t.name = name
  t.dbus_opts = {
    bus = "session",
    dest = "org.mpris.MediaPlayer2." .. name,
    interface = "org.mpris.MediaPlayer2.Player",
    path = "/org/mpris/MediaPlayer2",
  }

  setmetatable(t, self)
  self.__index = self
  return t
end

--- Toggle play/pause.
function media_player.MediaPlayer:play()
  ldbus.api.call_async(media_player_dbus(self, "PlayPause"))
end

--- Stop playback.
function media_player.MediaPlayer:stop()
    ldbus.api.call_async(media_player_dbus(self, "Stop"))
end

--- Go to the previous track in the playlist.
function media_player.MediaPlayer:previous()
  ldbus.api.call_async(media_player_dbus(self, "Previous"))
end

--- Go to the next track in the playlist.
function media_player.MediaPlayer:next()
  ldbus.api.call_async(media_player_dbus(self, "Next"))
end

--- Return the current position of the track in microseconds.
-- @return The current track position in microseconds, between 0 and the
-- `'mpris:length'` metadata entry.
-- @see media_player.MediaPlayer:metadata
function media_player.MediaPlayer:position()
  return media_player_dbus_property(self, "Position")
end

--- Return the position of the track as a string of the type
-- `HH:MM:SS`.
-- @return A string of the type `HH:MM:SS`
function media_player.MediaPlayer:position_as_str()
  return time_from_useconds_as_str(self:position())
end

--- Return the [metadata](https://www.freedesktop.org/wiki/Specifications/mpris-spec/metadata/)
-- associated to the current track.
-- @return A table containing the metadata.
function media_player.MediaPlayer:metadata()
  return media_player_dbus_property(self, "Metadata")
end

--- Return useful information about the track.
-- @return A table with the following string attributes
-- (if available in the track's metadata):
--
-- * `album`: name of the album
-- * `title`: title of the song
-- * `year`: song year
-- * `artists`: comma-separated list of artists (may be just one artist)
-- * `length`: total lenght of the track as `HH:MM:SS`
--
-- @see media_player.MediaPlayer:metadata
function media_player.MediaPlayer:info()
  local metadata = self:metadata()

  local info = {
    album = metadata["xesam:album"],
    title = metadata["xesam:title"],
    year = media_player.get_year(metadata["xesam:contentCreated"])
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

return media_player
