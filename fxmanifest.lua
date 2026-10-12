fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-Medical'
author 'XyraL'
description 'An all-in-one EMS and medical script for Qbox and QBCore. Replaces qbx_medical, qbx_ambulancejob and qb-ambulancejob.'
version '1.0.0'

provide 'qbx_medical'
provide 'qbx_ambulancejob'
provide 'qb-ambulancejob'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'shared/locale.lua',
    'shared/util.lua',
    'shared/body.lua',
    'shared/vitals.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/target.lua',
    'bridge/keys.lua',
    'bridge/fuel.lua',
    'client/ui.lua',
    'client/main.lua',
    'client/damage.lua',
    'client/effects.lua',
    'client/down.lua',
    'client/treat.lua',
    'client/menu.lua',
    'client/props.lua',
    'client/bed.lua',
    'client/hospital.lua',
    'client/pharmacy.lua',
    'client/surgery.lua',
    'client/equipment.lua',
    'client/tablet.lua',
    'client/calls.lua',
    'client/screens.lua',
    'client/placement.lua',
    'client/builder.lua',
    'client/compat.lua',
    'client/commands.lua',
    'client/fallbacks.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/keys.lua',
    'bridge/banking.lua',
    'bridge/dispatch.lua',
    'server/db.lua',
    'server/standdown.lua',
    'server/state.lua',
    'server/records.lua',
    'server/patients.lua',
    'server/calls.lua',
    'server/hospitals.lua',
    'server/down.lua',
    'server/treat.lua',
    'server/compat.lua',
    'server/actions.lua',
    'server/pharmacy.lua',
    'server/surgery.lua',
    'server/equipment.lua',
    'server/tablet.lua',
    'server/builder.lua',
    'server/commands.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/dui/screen.html',
}
