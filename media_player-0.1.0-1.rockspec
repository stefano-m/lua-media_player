package = "media_player"
 version = "0.1.0-1"
 source = {
    url = "git://github.com/stefano-m/awesome-media_player",
    tag = "v0.1.0"
 }
 description = {
    summary = "Control PulseAudio devices using DBus",
    detailed = "Control PulseAudio devices using DBus",
    homepage = "https://github.com/stefano-m/awesome-media_player",
    license = "GPL v3"
 }
 dependencies = {
    "lua >= 5.1",
    "ldbus_api >= 0.8"
 }
 supported_platforms = { "linux" }
 build = {
    type = "builtin",
    modules = { media_player = "media_player.lua" },
    copy_directories = { "doc" }
 }
