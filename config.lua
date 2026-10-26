Config = {}

Config.Locale = 'en'
Config.Debug = false

Config.Bridges = {
    framework = 'auto', -- 'auto', 'qbox' or 'qbcore'
    inventory = 'auto', -- 'auto', 'ox_inventory', 'qb-inventory', 'qs-inventory', 'ps-inventory', 'codem-inventory' or 'core_inventory'
    target = 'auto',    -- 'auto', 'ox_target', 'qb-target', 'sleepless_interact', 'interact', 'qtarget' or 'none' ([E] prompts)
    dispatch = 'auto',  -- where medical calls also go: 'auto', 'none', 'XS-Dispatch', 'ps-dispatch', 'qs-dispatch', 'cd_dispatch', 'core_dispatch', 'rcore_dispatch' or 'linden_outlawalert'
    keys = 'auto',      -- vehicle keys for ambulances: 'auto' or a resource name
    banking = 'auto',   -- where bills are paid into: 'auto' or a resource name
    fuel = 'auto',      -- 'auto', 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lc_fuel' or 'none'
}

Config.Admin = {
    command = 'medicalbuilder',         -- opens the hospital builder
    acePermission = 'xs.medical.admin', -- add_ace group.admin xs.medical.admin allow
    groups = { 'admin', 'god' },        -- framework permission groups that can open it
    licenses = {},                      -- 'license:...' identifiers that can always open it
}

-- Who counts as medical staff. A player with any of these job names, or a job of one of these types, is a medic.
Config.Jobs = {
    names = { 'ambulance', 'ems', 'doctor' },
    types = { 'ems' },
    requireDuty = true,      -- off-duty medics are treated like anyone else
    society = 'ambulance',   -- account that bills and check-in fees are paid into
}

-- Lowest job grade that can do each thing. Bosses can always do everything.
Config.Grades = {
    prescribe = 1,
    surgery = 2,
    editRecords = 1,
    editReports = 3, -- edit anyone's care report. Writers can always edit their own
    deleteReports = 3,
    manage = 4,      -- hire, fire and promote from the tablet
}

Config.Commands = {
    tablet = 'medtablet',  -- medics: opens the tablet. false to turn off
    tabletKey = 'F7',      -- default key for the tablet, players can rebind it. false for none
    injuries = 'injuries', -- anyone: shows your own injuries
    ems = '911e',          -- anyone: /911e what happened, calls medics to you. false to turn off
    revive = 'revive',     -- admins: /revive [id]
    heal = 'aheal',        -- admins: /aheal [id]
    kill = 'kill',         -- admins: /kill [id]
    diag = 'medicaldiag',  -- anyone: prints what XS-Medical detected, for support
    respond = 'medrespond', -- medics: takes the call on the alert and sets GPS. false to turn off
    respondKey = 'Y',       -- default key for respond, players can rebind it. false for none
    hideAlert = 'medhide',  -- medics: hides the call alert
    hideKey = 'U',          -- default key for hide, players can rebind it. false for none
}

-- The small vitals strip in the corner while you are hurt.
Config.Hud = {
    enabled = true,
}

Config.Tablet = {
    item = 'medical_tablet', -- using this item opens the tablet. false for no item
    needItem = false,        -- true: medics need the item to open the tablet at all, even with the key or command
    prop = true,             -- holds a tablet while it is open
    accent = '#2fbf6b',      -- tablet and alert colour, the same green XS-MDT uses for EMS
    -- The record pages. Turn any off if your server keeps medical records in another MDT.
    -- Patient, Calls and Hospital always stay: treating, call alerts and beds live there.
    pages = {
        records = true,   -- patient records
        prescribe = true, -- prescriptions
        reports = true,   -- care reports
        roster = true,    -- roster, callsigns, hiring and firing
    },
}

Config.Damage = {
    enabled = true,
    gameRegen = false,           -- GTA's own slow health regeneration
    ignoreBelow = 3,             -- hits that take less health than this do not leave a wound
    armourStops = 0.7,           -- chance body armour stops a bullet to the torso or stomach
    headshotDowns = true,        -- a bullet to the head puts you straight down
    bulletStaysIn = { torso = 0.6, stomach = 0.6, limb = 0.3 },
    fracture = { gunshot = 0.25, blunt = 0.15, fall = 0.45, vehicle = 0.35, blast = 0.3 },
    internal = { vehicle = 0.3, blast = 0.35, blunt = 0.05 }, -- internal bleeding, needs surgery
    maxPerPart = 3,              -- wounds of one kind on one body part merge past this
}

Config.Bleeding = {
    rates = { 0.04, 0.12, 0.3 },  -- blood lost per second at bleed level 1, 2 and 3 (out of 100)
    collapseAt = 55,              -- blood level that drops you
    regenPerMinute = 1.5,         -- blood back per minute while nothing is bleeding
    drops = true,                 -- blood drips on the ground while you bleed
}

Config.Effects = {
    limp = true,        -- a broken leg makes you limp and stops sprinting and jumping until it is splinted
    shakyAim = true,    -- a broken arm makes your aim shake until it is splinted
    concussion = true,  -- a head knock blurs your vision now and then
    pain = true,        -- strong pain pulses the screen
    bloodLoss = true,   -- low blood drains the colour and makes you stumble
}

Config.Down = {
    bleedOut = { 600, 420, 300, 180 }, -- seconds until cardiac arrest when the worst bleed is none, light, heavy, severe
    knockout = { enabled = true, seconds = 40 }, -- knocked out by fists with no bleeding: you come round on your own
    crawl = true,
    finishable = true,                 -- more damage while down stops the heart
    callCooldown = 45,                 -- seconds between calls for help
    autoCall = { enabled = true, chance = 0.6, delay = { 20, 50 } }, -- a passer-by calls it in if you do not
    respawnAfter = { ems = 300, noEms = 90 }, -- seconds before you can give up, with and without medics on duty
    holdToRespawn = 3,
}

Config.Arrest = {
    seconds = 240,     -- how long the heart can still be restarted
    shockable = 120,   -- the first part of that is a shockable rhythm the defibrillator can fix
    cprChance = 0.2,   -- chance one round of CPR alone restarts the heart
    shockChance = 0.65,
    adrenalineBonus = 0.2,
}

Config.Respawn = {
    bill = 500,
    account = 'bank',
    wipeInventory = false,
    keepItems = { 'id_card', 'driver_license', 'phone' }, -- kept when wipeInventory is on
    recoverSeconds = 25,                                  -- time in the hospital bed after respawning
    fallback = vec4(298.65, -584.5, 43.26, 72.0),         -- used when no hospital with a free bed has been built yet
    prison = { enabled = true, coords = vec4(1761.96, 2597.74, 45.66, 270.0) }, -- jailed players wake up in the prison infirmary
}

Config.CheckIn = {
    price = 250,        -- the nurse puts you in a bed and heals you for this, medics on duty or not
    account = 'bank',
    treatSeconds = { 5, 10 }, -- the nurse checks you over for a random time in this range, in seconds
    pageMedics = true,  -- when every bed is taken, you go on the waiting list and medics are paged
}

Config.Recovery = {
    bedHealPerSecond = 2,     -- health back per second while the nurse treats you. Lying in a bed on your own does nothing
}

-- What each supply does is built in. Change the item names to match your inventory, or set anyone = false
-- to keep a supply for medics only.
Config.Supplies = {
    bandage = { item = 'bandage', seconds = 4, anyone = true, self = true },
    tourniquet = { item = 'tourniquet', seconds = 3, anyone = true, self = true },
    gauze = { item = 'gauze', seconds = 5, anyone = true, self = false },
    splint = { item = 'splint', seconds = 5, anyone = true, self = false },
    burncream = { item = 'burncream', seconds = 4, anyone = true, self = true },
    painkillers = { item = 'painkillers', seconds = 3, anyone = true, self = true, relief = 2, minutes = 6 },
    morphine = { item = 'morphine', seconds = 4, anyone = false, self = false, relief = 6, minutes = 12, opioid = 3 },
    saline = { item = 'saline', seconds = 5, anyone = false, self = false, blood = 30 },
    adrenaline = { item = 'adrenaline', seconds = 3, anyone = false, self = false },
    defibrillator = { item = 'defibrillator', seconds = 5, anyone = false, self = false, consume = false },
    firstaid = { item = 'firstaid', seconds = 5, anyone = true, self = false, revives = true },
    ifaks = { item = 'ifaks', seconds = 5, anyone = true, self = true, heal = 25, relief = 2, minutes = 4 },
}

Config.Infection = {
    enabled = true,
    afterMinutes = 30, -- an open wound nobody cleaned up turns infected after this long
    drainPerMinute = 2,
}

-- Medicines a medic can prescribe and a pharmacist hands out. effect: 'pain', 'infection' or 'stress'.
Config.Medicines = {
    { item = 'oxycodone', label = 'Oxycodone', dose = '10 mg', price = 140, effect = 'pain', relief = 4, minutes = 25 },
    { item = 'amoxicillin', label = 'Amoxicillin', dose = '500 mg', price = 90, effect = 'infection' },
    { item = 'diazepam', label = 'Diazepam', dose = '5 mg', price = 110, effect = 'stress', amount = 40 },
}

Config.Prescriptions = {
    maxRefills = 5,
    expiresDays = 14,
}

-- Things a pharmacist sells over the counter, to anyone.
Config.Pharmacy = {
    account = 'cash',
    counter = {
        { item = 'painkillers', price = 45 },
        { item = 'bandage', price = 30 },
        { item = 'burncream', price = 60 },
    },
}

-- What the supply cabinet in a hospital stocks for on-duty medics. price 0 is free.
Config.Cabinet = {
    { item = 'bandage', price = 0 },
    { item = 'tourniquet', price = 0 },
    { item = 'gauze', price = 0 },
    { item = 'splint', price = 0 },
    { item = 'burncream', price = 0 },
    { item = 'painkillers', price = 0 },
    { item = 'morphine', price = 0, grade = 1 },
    { item = 'saline', price = 0, grade = 1 },
    { item = 'adrenaline', price = 0, grade = 1 },
    { item = 'defibrillator', price = 0, grade = 1 },
    { item = 'firstaid', price = 0 },
}

Config.Surgery = {
    seconds = 45,       -- time limit for one operation
    failBleed = 2,      -- a botched cut opens a wound bleeding this badly
}

Config.Dispatch = {
    builtin = true,       -- calls show on the medic tablet
    blipSeconds = 300,
    code = '10-52',
    sound = true,
    alertSeconds = 15,    -- how long a call alert stays up
}

Config.Vehicles = {
    platePrefix = 'EMS',
    fuel = 100.0,
    returnDistance = 25.0,
    defaults = { 'ambulance' },   -- offered in a new garage before you pick from your vehicles list
    helicopters = { 'polmav' },
}

-- offset and rotation place the prop and the patient. Swap in a streamed stretcher model and tune them to fit it.
Config.Stretcher = {
    model = 'v_med_emptybed',
    fromVehicles = { 'ambulance' },
    push = { reach = 0.45, lift = 0.0, turn = 0.0 }, -- lines up in front of you from the model's size. reach: gap to your hands, turn: extra degrees
    lie = { lift = 1.0, turn = 0.0 },                -- how high the patient lies on it, turn = 180 flips head and feet
}

Config.Wheelchair = {
    model = 'prop_wheelchair_01',
    push = { offset = vec3(0.0, -0.3, -0.73), rotation = vec3(195.0, 180.0, 180.0), bone = 28422 },
    seat = { offset = vec3(0.0, 0.0, 0.4), rotation = vec3(0.0, 0.0, 180.0) },
}

Config.Beds = {
    prop = 'v_med_bed1',   -- spawned on a placed bed when nothing is there yet. false to never spawn one
}

Config.Peds = {
    checkin = 's_f_y_scrubs_01',
    pharmacist = 's_m_m_doctor_01',
}

-- Patient boards, door signs and bedside monitors drawn on the walls.
Config.Screens = {
    enabled = true,
    drawDistance = 16.0,
    names = 'full',        -- 'full', 'initial' (Isabel F.) or 'initials' (I.F.)
    unknownNames = true,   -- patients nobody has checked the ID of show as Jane/John Doe
    maxLive = 8,           -- most screens drawn at once, nearest first
}

Config.Elevators = {
    fadeMs = 450,
}

Config.Blips = {
    hospital = { sprite = 61, colour = 2, scale = 0.8 },
    pharmacy = { sprite = 51, colour = 2, scale = 0.7 },
}

Config.Builder = {
    cameraSpeed = { normal = 6.0, fast = 18.0, slow = 1.5 },
    showExisting = true,
}

-- Admin menus that revive or heal through the old client events (qb-adminmenu and friends) are trusted once a minute
-- per player. Turn off if you only revive with /revive, txAdmin or the Revive export.
Config.Compat = {
    trustClientRevive = true,
}

-- Other resources that run their own death and damage. While a player is in one of their matches, XS-Medical stands down.
Config.Standdown = {
    arena = true, -- XS-Arena matches
}
