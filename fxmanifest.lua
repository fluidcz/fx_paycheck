fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'fd'
description 'FX Paycheck | Fluid Development'
version '2.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
    '@oxmysql/lib/MySQL.lua'
}

server_script 'game/src/sv/sv.lua'
client_script 'game/src/cl/cl.lua'
