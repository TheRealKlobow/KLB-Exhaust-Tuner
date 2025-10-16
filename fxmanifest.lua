fx_version 'cerulean'
game 'gta5'

author 'Klobow Audio'
description 'Server-synced exhaust audio customisation system'
version '1.0.0'

lua54 'yes'

ui_page 'html/main.html'

files {
    'html/main.html'
}

shared_scripts {
    'shared/shared_config.lua',
    'shared/locales.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
