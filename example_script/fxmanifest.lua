fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'tss_bridge_example'
author 'TinySprite'
description 'Portable consumer-side test lab for tss_bridge'
version '1.0.0'

dependency 'tss_bridge'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'
