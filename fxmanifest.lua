fx_version 'cerulean'
games { 'gta5' }

shared_script '@ox_lib/init.lua'

shared_script { 'config.lua' }

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/logo.png'
}

dependencies {
    'oxmysql',
    'ox_lib'
}

lua54 'yes'
