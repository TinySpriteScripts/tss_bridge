name "TSS_Bridge"
author "TinySprite"
version "0.0.1"
description "Framework Bridge By TinySprite"
fx_version "cerulean"
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
games { 'gta5', 'rdr3' }
lua54 'yes'

files {
    'starter.lua',
    'shared/*.lua',
    'shared/modules/*.lua',
    'shared/inventory/*.lua',
    'html/dist/index.html',
    'html/dist/**/*',
}

ui_page 'html/dist/index.html'

shared_scripts {
    'starter.lua',
}

-- Version checker
server_scripts {

}

client_scripts {

}

suppress_updates 'false'   -- set to 'true' to disable update pings
