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

--- Thin wrapper around pcall and dbus_proxy.Proxy:new
--
-- @return ok, value pair as returned by `pcall`. If `ok` is `true`, then
-- `value` is a `dbus_proxy.Proxy` object. Otherwise, `value` is an error
-- message (string)
--
local function get_proxy(name)
  return pcall(
    proxy.Proxy.new,
    proxy.Proxy,
    {
      bus = proxy.Bus.SESSION,
      name = "org.mpris.MediaPlayer2." .. name,
      interface = "org.mpris.MediaPlayer2.Player",
      path = "/org/mpris/MediaPlayer2"
  })
end

--- A dummy table that is returned instead of the actual proxy
-- if the application is not available.
local dummy = {}
setmetatable(dummy, {
               __call = function () end,
               __index = {},
               __newindex = function () end
})

local function is_connected(player)
  -- If Introspect returns nil, it means that we lost
  -- connection with the application (i.e. stale proxy).
  local disconnected =  (player._proxy == dummy)
    or (player._proxy:Introspect() == nil)
  return not disconnected
end

local function try_reconnect(player)
  local is_reconnected

  local connected = is_connected(player)

  if not connected then
    local ok, p = get_proxy(player.name)

    if ok then
      player._proxy = p
    end
    is_reconnected = ok
  else
    is_reconnected = not connected
  end

  return is_reconnected

end

--- @type MediaPlayer
local MediaPlayer = {}

--- Check whether the player object is connected to the actual media player via
--- DBus
-- @return whether the player is connected
-- @see MediaPlayer:try_reconnect
function MediaPlayer:is_connected()
  return is_connected(self)
end

--- Try to reconnect the proxy associated with the media player.
-- If successful, the `_proxy` property of `player` will be set to a new proxy
-- object. If the proxy is already connected, nothing happens.
-- @return whether the proxy was reconnected.
-- @see MediaPlayer:is_connected
function MediaPlayer:try_reconnect()
  return try_reconnect(self)
end

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
  local p = self._proxy
  if p == dummy then
    return nil
  end
  return p:Get(self.interface, property_name)
end


local function get_from_proxy(proxy_object, key)

  local value

  local value_from_proxy = proxy_object[key]

  if type(value_from_proxy) == "function" then

    value = function (_, ...)
      return value_from_proxy(proxy_object, ...)
    end

  elseif proxy_object.accessors[key] then

    -- Ensure we get the most up-to-date value.
    value = proxy_object:Get(proxy_object.interface, key)

  else

    value = value_from_proxy

  end

  return value
end

--- Return properties and methods from the underlying proxy object
-- transparently. If the proxy is not alive, return no-op values.
-- Used as `__index` key in the player's metatable.
local function get_key(player, key)

  local value

  local own_value = rawget(player, key)

  if own_value ~= nil then

    value = own_value

  elseif is_connected(player) or try_reconnect(player) then

    value = get_from_proxy(player._proxy, key)

  else

    value = dummy

  end

  return value

end

--- Return the position of the track as a string of the type
-- `HH:MM:SS`.
-- @return a string of the type `HH:MM:SS`
-- @return an empty string if the application is not available
function MediaPlayer:position_as_str()
  local pos = self.Position
  if pos == dummy then
    return ""
  end
  return time_from_useconds_as_str(pos)
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
  local metadata = self.Metadata

  if metadata == dummy then
    return {}
  end

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
  `org.mpris.MediaPlayer2.<name>`. E.g. `org.mpris.MediaPlayer2.vlc`. `name`
  will also be exposed as a field of the object (i.e. `player.name`)

]]
function MediaPlayer:new(name)

  local ok, p = get_proxy(name)

  local o = {
    _proxy = ok and p or dummy,
    name = name,
    info = self.info,
    position_as_str = self.position_as_str,
    Get = self.Get,
    is_connected = self.is_connected,
    try_reconnect = self.try_reconnect
  }
  setmetatable(o, {__index = get_key})
  return o
end

return MediaPlayer
