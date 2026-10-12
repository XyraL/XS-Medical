<h1 align="center">XS-Medical</h1>

<p align="center">An all-in-one EMS and medical script for <strong>QBox</strong> and <strong>QBCore</strong>. Replaces qbx_medical, qbx_ambulancejob and qb-ambulancejob.</p>

<p align="center">
  <a href="https://github.com/XyraL/XS-Medical/releases"><img src="https://img.shields.io/github/v/release/XyraL/XS-Medical?style=flat-square&color=3dff7a&label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/framework-QBox%20%7C%20QBCore-55dcff?style=flat-square" alt="framework">
  <img src="https://img.shields.io/badge/price-free-30d158?style=flat-square" alt="price">
  <a href="https://xyralscripts.dev/docs-xs-medical"><img src="https://img.shields.io/badge/docs-xyralscripts.dev-a889ff?style=flat-square" alt="docs"></a>
  <a href="https://discord.gg/XRURAw4TM2"><img src="https://img.shields.io/badge/support-discord-5865F2?style=flat-square" alt="support"></a>
</p>

<p align="center">
  <a href="https://xyralscripts.dev/xs-medical">Website</a> &nbsp;·&nbsp;
  <a href="https://xyralscripts.dev/docs-xs-medical">Setup guide</a> &nbsp;·&nbsp;
  <a href="https://github.com/XyraL/XS-Medical/releases">Releases</a> &nbsp;·&nbsp;
  <a href="https://discord.gg/XRURAw4TM2">Discord</a>
</p>

---

XS-Medical turns getting hurt into something to roleplay. A bullet lands in a body part and stays there until a surgeon takes it out. A leg bleeds until someone gets a tourniquet on it. Medics work from a tablet that looks like a bedside monitor, with the patient's heart trace, blood pressure and oxygen moving in real time.

It is the whole EMS job in one resource: hospitals you build in game, beds, check-in, NPC pharmacists, ambulances, a medic tablet with records and prescriptions, built-in medical dispatch, and screens on the hospital walls that show who is in which room.

## Features

- QBox and QBCore support
- Wounds on seven body parts: gunshots, stab wounds, cuts, burns, broken bones, concussions and internal bleeding
- Bleeding drains blood over time. Lose too much and you go down
- Down, out cold, no pulse: crawl, call for help, or wait for CPR and a defibrillator
- Broken legs limp, broken arms shake your aim, head knocks blur your vision
- Twelve supplies, each for a job: bandage, tourniquet, pressure dressing, splint, burn dressing, painkillers, morphine, IV saline, adrenaline, defibrillator, first aid kit and IFAK
- Medic tablet styled as a bedside monitor: live vitals, injuries, timeline, calls, records, prescriptions, roster, reports and beds
- Surgery in the operating theatre, as a three-step minigame per wound
- Prescriptions written on the tablet, filled by NPC pharmacists who pull the patient's record
- Patients nobody has identified show as Jane or John Doe until a medic checks their ID
- Patient boards, door signs and bedside monitors drawn on the hospital walls, updating live
- Built-in medical dispatch, and calls sent on to XS-Dispatch, ps-dispatch, qs-dispatch, cd_dispatch, core_dispatch, rcore_dispatch or linden_outlawalert if you run one
- In-game builder for hospitals and pharmacies: beds, check-in, operating tables, storage, supply cabinets, duty, garages, helipads, stretchers, wheelchairs, elevators, management, boards, signs and pharmacists
- Ambulances and helicopters picked from your own vehicles list, with keys and fuel
- Stretchers, wheelchairs and carrying, and loading patients into the back of an ambulance
- Hospital check-in with an NPC nurse when no medics are on duty, and a waiting list when there are
- Scripts that call qbx_medical, qbx_ambulancejob or qb-ambulancejob keep working
- Works with ox_target, qb-target, sleepless_interact, interact or qtarget, or E without one

## Requirements

- [qbx_core](https://github.com/Qbox-project/qbx_core) or [qb-core](https://github.com/qbcore-framework/qb-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- Optional: a target, a vehicle keys resource, a banking resource and a dispatch resource. They are picked up on their own

## Install

1. Stop qbx_medical, qbx_ambulancejob or qb-ambulancejob and take them out of `server.cfg`. XS-Medical answers for all three, so running both would fight over every death.
2. Drop `XS-Medical` into your resources folder.
3. Add it to `server.cfg` after its dependencies:
   ```
   ensure ox_lib
   ensure oxmysql
   ensure XS-Medical
   ```
4. Give your staff the builder:
   ```
   add_ace group.admin xs.medical.admin allow
   ```
5. Add the items. Paste `items/ox_inventory.lua` into `ox_inventory/data/items.lua`, or `items/qb_core.lua` into `qb-core/shared/items.lua`. Replace any entries with the same name (bandage, painkillers, firstaid and ifaks are already there on most servers).
6. Copy `inventory_images/*.png` into your inventory's image folder.
7. Restart the server. The tables are made on first start. `sql/xs_medical.sql` is there if you would rather run it yourself.
8. Run `/medicalbuilder` in game and build your first hospital.

Medics are anyone with a job named `ambulance`, `ems` or `doctor`, or a job of type `ems`. Change that in `Config.Jobs`.

## Building a hospital

`/medicalbuilder` opens the builder. Make a hospital, give it a name, and add points to it. Each point is placed with a free camera: fly to the spot and press Enter. Most points also have **At my spot**, which drops them where you stand.

| Point | What it does |
|---|---|
| Check-in | A nurse NPC or a desk. Patients check themselves in here |
| Beds | Patients lie here. Aim at a bed in your map and press F to snap to it. Give beds a room name |
| Operating tables | Where surgeons operate |
| Storage | A shared stash for medics on duty |
| Supply cabinets | Free supplies for medics on duty, set in `Config.Cabinet` |
| Duty clocks | Clock on and off |
| Garages and helipads | Pick the vehicles from your vehicles list, then set where they spawn |
| Stretchers and wheelchairs | Where staff grab one |
| Elevators | Floors with the same elevator name link up |
| Management | Opens the roster for bosses |
| Patient boards | A screen on a wall. Aim at the wall, scroll to size it |
| Door signs | A small screen by a door showing who is in that room |
| Pharmacists | Fills prescriptions and sells over the counter |

Beds can carry a **bedside monitor**: a screen next to the bed showing the live vitals of whoever is lying in it.

Pharmacies are their own places. Make one with **+ Pharmacy** and drop a pharmacist anywhere on the map.

Nothing is saved until you press **Save**. Closing the builder keeps what you were working on.

## Getting hurt

Every hit lands on a body part. What it leaves depends on what hit you:

- **Gunshots** bleed. In an arm or leg they can bleed badly and break the bone. In the chest or stomach the bullet may stay in, which needs surgery. A shot to the head puts you straight down
- **Knives** cut or stab, and a deep stab can bleed inside
- **Fists and bats** bruise, can break bones, and give concussions
- **Falls** hurt the legs and can break them
- **Cars** crush, break bones and can cause internal bleeding
- **Fire and explosions** burn

Body armour can stop a bullet to the chest or stomach. `/injuries` shows your own wounds, and lets you use your own supplies on them.

Blood drains while anything bleeds. Under 85% the colour fades, under 68% you start to stumble, and at 55% you go down.

## Going down

- **Down**: you are on the ground. Crawl with WASD, press G to call for help. A timer shows how long until your heart stops. Stopping the bleeding resets it
- **Out cold**: knocked out by fists with no bleeding. You come round on your own
- **No pulse**: your heart has stopped. CPR keeps the window open and a defibrillator can restart it, but only while the rhythm is still shockable
- **Flatline**: too late. Hold E to wake up in hospital

After a while you can hold E to give up and wake up in a hospital bed, with a bill. With medics on duty the wait is longer. Jailed players wake up in the prison infirmary.

A passer-by calls it in for you some of the time if you do not.

## Treating patients

Medics use the target on a patient, or open the tablet with **F7** (`/medtablet`). The tablet's Patient page shows each wound and what it needs. Click one to treat it.

| Supply | Does | Who |
|---|---|---|
| Bandage | Slows bleeding from a wound | Anyone, on themselves too |
| Tourniquet | Stops an arm or leg bleeding | Anyone, on themselves too |
| Pressure dressing | Packs a bleeding wound anywhere | Anyone |
| Splint | Holds a broken arm or leg, so the limp and shaking stop | Anyone |
| Burn dressing | Covers a burn | Anyone, on themselves too |
| Painkillers | Takes the edge off the pain | Anyone, on themselves too |
| Morphine | Strong pain relief. Too much slows the breathing | Medics |
| IV saline | Puts blood volume back over time | Medics |
| Adrenaline | Wakes a downed patient whose bleeding has stopped, or helps restart a heart | Medics |
| Defibrillator | Shocks a heart that has stopped. Not used up | Medics |
| First aid kit | Gets someone up if they are not bleeding badly | Anyone |
| IFAK | Bandage, pain relief and a little health | Anyone, on themselves too |

CPR needs no item. Everything is in `Config.Supplies`, including who can use what.

Wounds left open for half an hour turn infected. Amoxicillin from the pharmacy clears them.

## The medic tablet

| Page | What is on it |
|---|---|
| Patient | Live vitals, heart trace, injuries with what each needs, the visit timeline and actions |
| Calls | Medical calls with GPS, take or leave a call |
| Records | Search anyone. Blood type, allergies, conditions, notes, history and prescriptions |
| Prescribe | Write a prescription for the pharmacy |
| Roster | Who is on duty and their callsigns. Bosses hire, fire and promote here |
| Reports | Patient care reports, filled in from the visit timeline |
| Hospital | Every bed and who is in it, and who is waiting |

Records and prescriptions stay hidden until the patient's ID is checked.

## Surgery

Bullets left in, internal bleeding and bad breaks need an operating table. Put the patient on the table and start from the tablet or the table. Each wound is three steps: an incision, a repair, and sutures. Get two of three right and the wound is fixed. Fail and it bleeds again.

The lowest rank that can operate is `Config.Grades.surgery`.

## Prescriptions and pharmacies

A medic writes a prescription on the tablet. The patient walks up to any pharmacist, who pulls their record and fills it. Each prescription has a quantity, refills and an expiry. Pharmacists also sell painkillers, bandages and burn dressing over the counter.

The medicines and their prices are in `Config.Medicines`.

## Screens on the walls

- **Patient boards** list everyone at that hospital: room, name, status, medic and how long they have been in. Set the rooms a board lists, or leave it empty for all of them
- **Door signs** show who is in that room, or that it is free
- **Bedside monitors** show the live vitals of whoever is in the bed

Names can be full, first name and initial, or initials only (`Config.Screens.names`). Screens only draw when someone is close.

## Dispatch

Calls for help, passer-by reports, `/911e` and officer-down calls go to every medic on duty, on the tablet and as a pager message. If you run XS-Dispatch, ps-dispatch, qs-dispatch, cd_dispatch, core_dispatch, rcore_dispatch or linden_outlawalert, they get the call too. Pick one in `Config.Bridges.dispatch`, or set it to `'none'`.

## Coming from qbx_medical or qb-ambulancejob

There is nothing to move. `isdead`, `inlaststand` and `armor` are kept in the same place, and the old exports and events still answer:

- qbx_medical exports such as `Revive`, `Heal`, `IsDead`, `IsLaststand` and `GetPlayerStatus`
- qb-ambulancejob events such as `hospital:client:Revive`, `hospital:client:HealInjuries` and `hospital:server:ambulanceAlert`
- The `qbx_medical:deathState` and `isDead` state bags, for radial menus and radios
- txAdmin's heal button

Admin menus that revive through the old client events are trusted once a minute per player. Turn that off with `Config.Compat.trustClientRevive` if you only revive with `/revive`, txAdmin or the `Revive` export.

## Commands

| Command | Who | What |
|---|---|---|
| `/medicalbuilder` | Admins | Opens the builder |
| `/medtablet` (F7) | Medics | Opens the tablet |
| `/injuries` | Everyone | Shows your own wounds |
| `/911e message` | Everyone | Calls medics to you |
| `/revive [id]` | Admins | Revives and heals |
| `/aheal [id]` | Admins | Heals |
| `/kill [id]` | Admins | Stops their heart |
| `/medicaldiag` | Everyone | Shows what XS-Medical picked up, for support |

## Exports

Server:

```lua
exports['XS-Medical']:Revive(source)            -- or -1 for everyone
exports['XS-Medical']:Heal(source)
exports['XS-Medical']:IsDown(source)
exports['XS-Medical']:GetVitals(source)
exports['XS-Medical']:GetInjuries(source)
exports['XS-Medical']:GetDoctorCount()
exports['XS-Medical']:CreateCall({ coords = vec3, title = 'Person down', message = 'Car crash', priority = 1 })
exports['XS-Medical']:SetPaused(source, true)  -- stand down for this player, for minigames with their own death
```

Client:

```lua
exports['XS-Medical']:GetState()
exports['XS-Medical']:GetVitals()
exports['XS-Medical']:IsDown()
exports['XS-Medical']:SetPaused(true)
```

XS-Arena matches are left alone without any setup.

## License

See [LICENSE](LICENSE).
