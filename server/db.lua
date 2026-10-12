Db = { ready = false }

local TABLES = {
    [[
        CREATE TABLE IF NOT EXISTS `xs_medical_places` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `kind` VARCHAR(16) NOT NULL,
            `name` VARCHAR(64) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_medical_records` (
            `citizenid` VARCHAR(64) NOT NULL,
            `name` VARCHAR(96) NOT NULL DEFAULT '',
            `dob` VARCHAR(32) NOT NULL DEFAULT '',
            `female` TINYINT(1) NOT NULL DEFAULT 0,
            `blood` VARCHAR(4) NOT NULL DEFAULT '',
            `allergies` TEXT NULL,
            `conditions` TEXT NULL,
            `notes` TEXT NULL,
            `updated_by` VARCHAR(96) NOT NULL DEFAULT '',
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_medical_history` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(64) NOT NULL,
            `kind` VARCHAR(24) NOT NULL,
            `summary` VARCHAR(255) NOT NULL DEFAULT '',
            `data` LONGTEXT NULL,
            `medic_cid` VARCHAR(64) NOT NULL DEFAULT '',
            `medic_name` VARCHAR(96) NOT NULL DEFAULT '',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_medical_prescriptions` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(64) NOT NULL,
            `patient_name` VARCHAR(96) NOT NULL DEFAULT '',
            `item` VARCHAR(64) NOT NULL,
            `label` VARCHAR(64) NOT NULL DEFAULT '',
            `dose` VARCHAR(32) NOT NULL DEFAULT '',
            `qty` INT NOT NULL DEFAULT 1,
            `refills` INT NOT NULL DEFAULT 0,
            `notes` VARCHAR(255) NOT NULL DEFAULT '',
            `prescriber_cid` VARCHAR(64) NOT NULL DEFAULT '',
            `prescriber_name` VARCHAR(96) NOT NULL DEFAULT '',
            `status` VARCHAR(16) NOT NULL DEFAULT 'active',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `expires_at` DATETIME NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_medical_reports` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(64) NOT NULL DEFAULT '',
            `patient_name` VARCHAR(96) NOT NULL DEFAULT '',
            `title` VARCHAR(128) NOT NULL DEFAULT '',
            `body` TEXT NULL,
            `data` LONGTEXT NULL,
            `author_cid` VARCHAR(64) NOT NULL DEFAULT '',
            `author_name` VARCHAR(96) NOT NULL DEFAULT '',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_medical_staff` (
            `citizenid` VARCHAR(64) NOT NULL,
            `callsign` VARCHAR(16) NOT NULL DEFAULT '',
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

function Db.Setup()
    for _, statement in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, statement)
        if not ok then
            print(('^1[XS-Medical]^0 could not create a table: %s'):format(tostring(err)))
            return false
        end
    end
    Db.ready = true
    return true
end

function Db.Json(value)
    local ok, out = pcall(json.encode, value)
    return ok and out or '{}'
end

function Db.Decode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, out = pcall(json.decode, value)
    if ok and out ~= nil then return out end
    return fallback
end
