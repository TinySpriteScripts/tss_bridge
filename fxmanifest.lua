name "TSS_Bridge"
author "TinySprite"
version "1.5.0"
description "Framework Bridge By TinySprite"
fx_version "cerulean"
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
games { 'gta5', 'rdr3' }
lua54 'yes'

files {
    'shared/*.lua',
    'shared/locales/*.lua',
    'modules/**/shared.lua',
    'modules/inventory/adapters/*.lua',
    'html/dist/index.html',
    'html/dist/**/*',
}

ui_page 'html/dist/index.html'

shared_scripts {
    'shared/config.lua',
    'shared/helpers.lua',
    'shared/loader.lua',
    'bridge_lab/config.lua',
}

client_scripts {
    'modules/**/client.lua',
    'shared/export.lua',
    'bridge_lab/client/polyzone_creator.lua',
    'bridge_lab/client/main.lua',
}
server_scripts {
    'modules/**/server.lua',
    'shared/export.lua',
    'bridge_lab/server_config.lua',
    'bridge_lab/authorization.lua',
    'bridge_lab/configuration.lua',
    'bridge_lab/polyzone_storage.lua',
    'bridge_lab/server/main.lua',
}

suppress_updates 'false'   -- set to 'true' to disable update pings
