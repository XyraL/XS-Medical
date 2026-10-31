# Changelog

## [1.0.1] — 2026-10-30

- Switching character resets you to healthy, frees your bed, closes the tablet and menus, and ends carrying, treatments, bills and calls
- A model or animation that will not load no longer freezes treatment, equipment or every progress bar on the server

Replace everything except your config.lua. No SQL to run.

## [1.0.0] — 2026-10-26

The first beta. Everything is in, and it needs testing on real servers. If something breaks or feels wrong, tell me on Discord.

- Replaces qbx_medical, qbx_ambulancejob and qb-ambulancejob. Scripts that call them keep working
- Wounds on seven body parts: gunshots, stabs, cuts, burns, broken bones, concussions and internal bleeding
- Bleeding drains blood over time, and too little puts you down
- Down, out cold, no pulse and flatline, with crawling, calling for help, CPR and a defibrillator
- Broken legs limp, broken arms shake your aim, head knocks blur your vision
- Twelve medical supplies, each for its own job
- Treatments take 3 to 5 seconds and a wound is gone as soon as it is treated
- Medic tablet in the XS-MDT style: live monitor, injuries, calls, records, prescriptions, roster, reports and beds
- Using another MDT? Turn off the records, prescriptions, care reports or roster pages in the config
- A medical tablet item, and the option to need it to open the tablet
- Call alerts on screen. Y takes the call and sets GPS, U hides it
- Surgery as a three-step minigame per wound
- Prescriptions filled by NPC pharmacists who pull the patient's record
- Unidentified patients show as Jane or John Doe until a medic checks their ID
- Patient boards, door signs and bedside monitors on the hospital walls, updating live
- Built-in medical dispatch, and calls sent on to seven dispatch resources
- Personal lockers for every medic
- In-game builder for hospitals and pharmacies
- Ambulances and helicopters picked from your vehicles list
- Stretchers and wheelchairs you push, set down and pick back up, carrying, and loading patients into ambulances
- Everything a medic does also works by targeting the patient
- Care reports with incident time, patient, crew, vitals, injuries, treatment and outcome
- Map blip for each hospital, placed where you want with its own icon and colour
- Hospital check-in: a nurse beds you and heals you for a fee
- Medics finish a patient with Discharge, which heals them fully
- Works with ox_target, qb-target, sleepless_interact, interact or qtarget, or E without one
