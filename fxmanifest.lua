name "TSS_Bridge"
author "TinySprite"
version "1.1.0"
description "Framework Bridge By TinySprite"
fx_version "cerulean"
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
games { 'gta5', 'rdr3' }
lua54 'yes'

files {
    'shared/*.lua',
    'shared/locales/*.lua',
    'shared/modules/*.lua',
    'shared/inventory/*.lua',
    'html/dist/index.html',
    'html/dist/**/*',
}

ui_page 'html/dist/index.html'

shared_scripts {
    'shared/config.lua',
    'shared/helpers.lua',
    'shared/loader.lua',
}

client_scripts {
    'client/modules.lua',
    'client/transport.lua',
}
server_scripts {
    'server/modules.lua',
    'server/runtime.lua',
}

suppress_updates 'false'   -- set to 'true' to disable update pings
