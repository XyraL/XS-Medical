-- Paste these into ox_inventory/data/items.lua, replacing any entries with the same name.
-- Images: copy inventory_images/*.png into ox_inventory/web/images.

['bandage'] = {
    label = 'Bandage',
    weight = 100,
    description = 'Slows bleeding from cuts and wounds.',
    client = { export = 'XS-Medical.useItem' },
},

['tourniquet'] = {
    label = 'Tourniquet',
    weight = 150,
    description = 'Stops heavy bleeding from an arm or a leg.',
    client = { export = 'XS-Medical.useItem' },
},

['gauze'] = {
    label = 'Pressure Dressing',
    weight = 120,
    description = 'Packs a bleeding wound on the body.',
    client = { export = 'XS-Medical.useItem' },
},

['splint'] = {
    label = 'Splint',
    weight = 400,
    description = 'Holds a broken arm or leg still.',
    client = { export = 'XS-Medical.useItem' },
},

['burncream'] = {
    label = 'Burn Dressing',
    weight = 150,
    description = 'Cools and covers a burn.',
    client = { export = 'XS-Medical.useItem' },
},

['painkillers'] = {
    label = 'Painkillers',
    weight = 50,
    description = 'Takes the edge off the pain.',
    client = { export = 'XS-Medical.useItem' },
},

['morphine'] = {
    label = 'Morphine',
    weight = 60,
    description = 'Strong pain relief. Medics only.',
    client = { export = 'XS-Medical.useItem' },
},

['saline'] = {
    label = 'IV Saline',
    weight = 600,
    description = 'Puts volume back after blood loss. Medics only.',
    client = { export = 'XS-Medical.useItem' },
},

['adrenaline'] = {
    label = 'Adrenaline',
    weight = 60,
    description = 'Wakes a stable patient or helps restart a heart. Medics only.',
    client = { export = 'XS-Medical.useItem' },
},

['defibrillator'] = {
    label = 'Defibrillator',
    weight = 2500,
    stack = false,
    description = 'Shocks a heart in a shockable rhythm. Medics only.',
    client = { export = 'XS-Medical.useItem' },
},

['firstaid'] = {
    label = 'First Aid Kit',
    weight = 1500,
    description = 'Gets someone back on their feet if they are not bleeding badly.',
    client = { export = 'XS-Medical.useItem' },
},

['ifaks'] = {
    label = 'IFAK',
    weight = 300,
    description = 'Bandage, pain relief and a little health.',
    client = { export = 'XS-Medical.useItem' },
},

['oxycodone'] = {
    label = 'Oxycodone',
    weight = 30,
    description = 'Prescription pain relief.',
    client = { export = 'XS-Medical.useItem' },
},

['amoxicillin'] = {
    label = 'Amoxicillin',
    weight = 30,
    description = 'Prescription antibiotic. Clears an infected wound.',
    client = { export = 'XS-Medical.useItem' },
},

['diazepam'] = {
    label = 'Diazepam',
    weight = 30,
    description = 'Prescription. Calms the nerves.',
    client = { export = 'XS-Medical.useItem' },
},

['medical_tablet'] = {
    label = 'Medical Tablet',
    weight = 800,
    stack = false,
    description = 'Patients, calls, records and beds. Medics only.',
    client = { export = 'XS-Medical.useItem' },
},
