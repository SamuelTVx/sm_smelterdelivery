fx_version 'cerulean'
game 'gta5'

author 'SamuelTV'
description 'Smelter Delivery System!'
version '1.0.0'

server_scripts {
	'shared/sh_config.lua',
	'@es_extended/imports.lua',
	'server/*.lua'
}

client_scripts {
	'shared/sh_config.lua',
	'@es_extended/imports.lua',
	'client/*.lua'
}

shared_scripts {
	'shared/*.lua',
    '@es_extended/imports.lua',
    '@ox_lib/init.lua'
}
