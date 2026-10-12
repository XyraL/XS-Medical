Banking = { name = nil }

if not IsDuplicityVersion() or not Config then return end

local SUPPORTED = {
    'Renewed-Banking', 'qb-banking', 'okokBanking', 'tgg-banking', 'wasabi_banking', 'fd_banking', 'qb-management',
}

do
    local forced = Config.Bridges and Config.Bridges.banking or 'auto'
    if forced == 'none' then
        Banking.name = nil
    elseif forced ~= 'auto' then
        Banking.name = forced
    else
        for _, resource in ipairs(SUPPORTED) do
            if GetResourceState(resource) == 'started' then Banking.name = resource break end
        end
    end
end

local function number(value)
    if type(value) == 'table' then
        value = value.balance or value.amount or value.money or value.account_balance
    end
    return math.floor(tonumber(value) or 0)
end

local function ensure(name)
    if Banking.name == 'Renewed-Banking' then
        if exports['Renewed-Banking']:getAccountMoney(name) == false then
            exports['Renewed-Banking']:CreateJobAccount({ name = name, label = name }, 0)
        end
    elseif Banking.name == 'qb-banking' then
        if not exports['qb-banking']:GetAccount(name) then
            exports['qb-banking']:CreateJobAccount(name, 0)
        end
    elseif Banking.name == 'tgg-banking' then
        if exports['tgg-banking']:GetSocietyAccountMoney(name) == nil then
            exports['tgg-banking']:CreateBusinessAccount(name, 0, name)
        end
    end
end

function Banking.Balance(name)
    if not Banking.name then return 0 end
    local balance = 0
    pcall(function()
        if Banking.name == 'Renewed-Banking' then
            balance = exports['Renewed-Banking']:getAccountMoney(name)
        elseif Banking.name == 'qb-banking' then
            balance = exports['qb-banking']:GetAccountBalance(name)
        elseif Banking.name == 'okokBanking' then
            balance = exports.okokBanking:GetAccount(name)
        elseif Banking.name == 'tgg-banking' then
            balance = exports['tgg-banking']:GetSocietyAccountMoney(name)
        elseif Banking.name == 'wasabi_banking' then
            balance = exports.wasabi_banking:GetAccountBalance(name, 'society')
        elseif Banking.name == 'fd_banking' then
            balance = exports.fd_banking:GetAccount(name)
        elseif Banking.name == 'qb-management' then
            balance = exports['qb-management']:GetAccount(name)
        end
    end)
    return number(balance)
end

function Banking.Deposit(name, amount, note)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not Banking.name or not name or name == '' then return false end
    local ok, result = pcall(function()
        ensure(name)
        if Banking.name == 'Renewed-Banking' then
            return exports['Renewed-Banking']:addAccountMoney(name, amount)
        elseif Banking.name == 'qb-banking' then
            return exports['qb-banking']:AddMoney(name, amount, note)
        elseif Banking.name == 'okokBanking' then
            return exports.okokBanking:AddMoney(name, amount)
        elseif Banking.name == 'tgg-banking' then
            return exports['tgg-banking']:AddSocietyMoney(name, amount)
        elseif Banking.name == 'wasabi_banking' then
            return exports.wasabi_banking:AddMoney('society', name, amount)
        elseif Banking.name == 'fd_banking' then
            return exports.fd_banking:AddMoney(name, amount)
        elseif Banking.name == 'qb-management' then
            return exports['qb-management']:AddMoney(name, amount)
        end
    end)
    if not ok or result == false then
        print(('^3[XS-Medical]^0 %s did not take $%d into "%s".'):format(Banking.name, amount, name))
        return false
    end
    return true
end
