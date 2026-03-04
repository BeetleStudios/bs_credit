local QBCore = Config.Framework == 'qb-core' and exports['qb-core']:GetCoreObject() or nil
local ESX = Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' and exports['es_extended']:getSharedObject() or nil

local function GetESXGradeLabel(jobName, gradeLevel)
    if not jobName or gradeLevel == nil then return 'Unknown' end
    local row = MySQL.single.await('SELECT label FROM job_grades WHERE job_name = ? AND grade = ?', { jobName, tonumber(gradeLevel) or 0 })
    return (row and row.label) or 'Unknown'
end

local function GetESXBankMoney(xPlayer)
    if not xPlayer then return 0 end
    local accounts = xPlayer.getAccounts and xPlayer.getAccounts() or {}
    local bank = accounts.bank
    if type(bank) == 'number' then
        return bank
    end
    if type(bank) == 'table' and bank.money ~= nil then
        return tonumber(bank.money) or 0
    end
    local acc = xPlayer.getAccount and xPlayer.getAccount('bank')
    if acc then
        if type(acc) == 'number' then return acc end
        if type(acc) == 'table' and acc.money ~= nil then
            return tonumber(acc.money) or 0
        end
    end
    return 0
end

local function NormalizeESXPlayer(xPlayer)
    if not xPlayer then return nil end
    local job = xPlayer.getJob()
    local citizenid = (xPlayer.getSSN and xPlayer.getSSN()) or xPlayer.getIdentifier()
    local gradeLabel = (job and (job.name and job.grade ~= nil)) and GetESXGradeLabel(job.name, job.grade) or 'Unknown'
    return {
        PlayerData = {
            citizenid = citizenid,
            job = {
                name = job and job.name or 'unknown',
                label = job and job.label or 'Unknown',
                grade = job and { name = gradeLabel } or nil
            },
            money = { bank = GetESXBankMoney(xPlayer) },
            charinfo = {
                firstname = xPlayer.get('firstname') or xPlayer.get('firstName') or 'Unknown',
                lastname = xPlayer.get('lastname') or xPlayer.get('lastName') or 'Unknown',
                birthdate = xPlayer.get('dateofbirth') or xPlayer.get('dateOfBirth') or 'Unknown'
            }
        }
    }
end

local function GetPlayer(source)
    if Config.Framework == 'qbx_core' then
        return exports.qbx_core:GetPlayer(source)
    end
    if QBCore then
        return QBCore.Functions.GetPlayer(source)
    end
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        return NormalizeESXPlayer(xPlayer)
    end
    return nil
end

local function GetPlayerByCitizenId(citizenid)
    if Config.Framework == 'qbx_core' then
        return exports.qbx_core:GetPlayerByCitizenId(citizenid)
    end
    if QBCore then
        return QBCore.Functions.GetPlayerByCitizenId(citizenid)
    end
    if ESX then
        local xPlayer = nil
        if ESX.GetExtendedPlayers then
            for _, player in pairs(ESX.GetExtendedPlayers()) do
                if player.getSSN and player.getSSN() == citizenid then
                    xPlayer = player
                    break
                end
            end
        end
        if not xPlayer and ESX.GetPlayerFromIdentifier then
            xPlayer = ESX.GetPlayerFromIdentifier(citizenid)
        end
        if not xPlayer and ESX.GetExtendedPlayers then
            for _, player in pairs(ESX.GetExtendedPlayers()) do
                if player.getIdentifier and player.getIdentifier() == citizenid then
                    xPlayer = player
                    break
                end
            end
        end
        return NormalizeESXPlayer(xPlayer)
    end
    return nil
end

local function GetOfflinePlayer(citizenid)
    if Config.Framework == 'qbx_core' then
        return exports.qbx_core:GetOfflinePlayer(citizenid)
    end
    if QBCore then
        return QBCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
    end
    if ESX then
        local row = MySQL.single.await('SELECT * FROM users WHERE ssn = ?', { citizenid })
        if not row then return nil end
        local accounts = {}
        if row.accounts then
            accounts = type(row.accounts) == 'string' and json.decode(row.accounts) or row.accounts or {}
        end
        local bankMoney = 0
        if accounts.bank ~= nil then
            bankMoney = type(accounts.bank) == 'table' and (tonumber(accounts.bank.money) or 0) or tonumber(accounts.bank) or 0
        end
        if bankMoney == 0 and row.bank ~= nil then
            bankMoney = tonumber(row.bank) or 0
        end
        local rowId = row.ssn
        local gradeLabel = GetESXGradeLabel(row.job, row.job_grade)
        return {
            PlayerData = {
                citizenid = rowId,
                job = {
                    name = row.job or 'unemployed',
                    label = row.job or 'Unknown',
                    grade = { name = gradeLabel }
                },
                money = { bank = bankMoney },
                charinfo = {
                    firstname = row.firstname or 'Unknown',
                    lastname = row.lastname or 'Unknown',
                    birthdate = row.dateofbirth or 'Unknown'
                }
            }
        }
    end
    return nil
end

local function HasBankerJob(jobName)
    if not jobName then return false end
    local allowed = Config.BankerJob
    if type(allowed) == 'string' then
        return jobName == allowed
    end
    if type(allowed) == 'table' then
        for _, j in ipairs(allowed) do
            if j == jobName then return true end
        end
    end
    return false
end

local function HandleCreditReportCommand(source, args, rawCommand)
    local player = GetPlayer(source)
    if not player then 
        return 
    end
    
    -- Check if player has banker job
    local playerJob = player.PlayerData.job
    local jobName = playerJob and playerJob.name

    if not HasBankerJob(jobName) then
        if lib then
            lib.notify(source, {
                title = 'Access Denied',
                description = 'You must be a banker to use this command. Your job: ' .. (jobName or 'none'),
                type = 'error'
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {'System', 'You must be a banker to use this command.'}
            })
        end
        return
    end
    
    local citizenid = nil
    if args and type(args) == 'table' then
        if args.citizenid then
            citizenid = args.citizenid
        elseif args[1] then
            citizenid = args[1]
        end
    end
    
    TriggerClientEvent('bs_credit:client:openCreditReport', source, citizenid)
end

-- Helper function to get or create credit score
local function GetOrCreateCreditScore(citizenid)
    local result = MySQL.single.await('SELECT * FROM credit_scores WHERE citizenid = ?', { citizenid })
    
    if not result then
        -- Create new credit score with base score
        MySQL.insert.await('INSERT INTO credit_scores (citizenid, score) VALUES (?, ?)', { citizenid, Config.BaseCreditScore })
        return {
            citizenid = citizenid,
            score = Config.BaseCreditScore,
            last_updated = os.time()
        }
    end
    
    return result
end

-- Get credit history
local function GetCreditHistory(citizenid, limit)
    limit = limit or 50
    local history = MySQL.query.await('SELECT * FROM credit_history WHERE citizenid = ? ORDER BY created_at DESC LIMIT ?', { citizenid, limit })
    return history or {}
end

-- Get credit score for a citizenid
local function GetCreditScore(citizenid)
    local creditData = GetOrCreateCreditScore(citizenid)
    return creditData.score
end

-- Add to credit score
local function AddCreditScore(citizenid, amount, description)
    if not citizenid or not amount or amount <= 0 then
        return false
    end
    
    local creditData = GetOrCreateCreditScore(citizenid)
    local newScore = math.min(creditData.score + amount, Config.MaxCreditScore)
    
    -- Update credit score
    MySQL.update.await('UPDATE credit_scores SET score = ? WHERE citizenid = ?', { newScore, citizenid })
    
    -- Add to history
    MySQL.insert.await('INSERT INTO credit_history (citizenid, change_amount, description) VALUES (?, ?, ?)', {
        citizenid,
        amount,
        description or 'Credit score increase'
    })
    
    return true, newScore
end

-- Reduce credit score
local function ReduceCreditScore(citizenid, amount, description)
    if not citizenid or not amount or amount <= 0 then
        return false
    end
    
    local creditData = GetOrCreateCreditScore(citizenid)
    local newScore = math.max(creditData.score - amount, Config.MinCreditScore)
    
    -- Update credit score
    MySQL.update.await('UPDATE credit_scores SET score = ? WHERE citizenid = ?', { newScore, citizenid })
    
    -- Add to history (negative amount)
    MySQL.insert.await('INSERT INTO credit_history (citizenid, change_amount, description) VALUES (?, ?, ?)', {
        citizenid,
        -amount,
        description or 'Credit score decrease'
    })
    
    return true, newScore
end

local function HandleAddCreditCommand(source, args, rawCommand)
    local player = GetPlayer(source)
    if not player then 
        return 
    end
    
    local citizenid = nil
    local amount = nil
    local description = nil
    
    if args and type(args) == 'table' then
        citizenid = args[1] or args.citizenid
        amount = tonumber(args[2] or args.amount)
        description = args[3] or args.description
    end
    
    if not citizenid or not amount or amount <= 0 then
        if lib then
            lib.notify(source, {
                title = 'Error',
                description = 'Usage: /addcredit [citizenid] [amount] [description]',
                type = 'error'
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {'System', 'Usage: /addcredit [citizenid] [amount] [description]'}
            })
        end
        return
    end
    
    local success, newScore = AddCreditScore(citizenid, amount, description)
    if success then
        if lib then
            lib.notify(source, {
                title = 'Success',
                description = 'Credit score updated. New score: ' .. newScore,
                type = 'success'
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {'System', 'Credit score updated. New score: ' .. newScore}
            })
        end
    else
        if lib then
            lib.notify(source, {
                title = 'Error',
                description = 'Failed to add credit score.',
                type = 'error'
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {'System', 'Failed to add credit score.'}
            })
        end
    end
end

local function HandleReduceCreditCommand(source, args, rawCommand)
    local player = GetPlayer(source)
    if not player then 
        return 
    end
    
    local citizenid = nil
    local amount = nil
    local description = nil
    
    if args and type(args) == 'table' then
        citizenid = args[1] or args.citizenid
        amount = tonumber(args[2] or args.amount)
        description = args[3] or args.description
    end
    
    if not citizenid or not amount or amount <= 0 then
        if lib then
            lib.notify(source, {
                title = 'Error',
                description = 'Usage: /reducecredit [citizenid] [amount] [description]',
                type = 'error'
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {'System', 'Usage: /reducecredit [citizenid] [amount] [description]'}
            })
        end
        return
    end
    
    local success, newScore = ReduceCreditScore(citizenid, amount, description)
    if success then
        if lib then
            lib.notify(source, {
                title = 'Success',
                description = 'Credit score updated. New score: ' .. newScore,
                type = 'success'
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {'System', 'Credit score updated. New score: ' .. newScore}
            })
        end
    else
        if lib then
            lib.notify(source, {
                title = 'Error',
                description = 'Failed to reduce credit score.',
                type = 'error'
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {'System', 'Failed to reduce credit score.'}
            })
        end
    end
end

RegisterCommand('creditreport', HandleCreditReportCommand, false)

if Config.EnableCreditCommands then
    RegisterCommand('addcredit', HandleAddCreditCommand, false)
    RegisterCommand('reducecredit', HandleReduceCreditCommand, false)
end

CreateThread(function()
    while not lib do
        Wait(100)
    end

    -- Initialize database tables
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `credit_scores` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `score` INT(11) NOT NULL DEFAULT 650,
            `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `credit_history` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `change_amount` INT(11) NOT NULL,
            `description` TEXT,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    lib.callback.register('bs_credit:server:getCreditReport', function(source, citizenid)
        local idLabel = (Config.Framework == 'esx') and 'SSN' or 'Citizen ID'
        if not citizenid or citizenid == '' then
            lib.notify(source, {
                title = 'Error',
                description = 'No ' .. idLabel:lower() .. ' provided.',
                type = 'error'
            })
            return nil
        end
        
        local player = GetPlayer(source)
        if not player then
            return nil
        end
        
        local playerJob = player.PlayerData.job
        local jobName = playerJob and playerJob.name
        if not HasBankerJob(jobName) then
            lib.notify(source, {
                title = 'Access Denied',
                description = 'You must be a banker to access credit reports.',
                type = 'error'
            })
            return nil
        end
        
        local targetPlayer = GetPlayerByCitizenId(citizenid)
        local offlinePlayer = nil
        
        if not targetPlayer then
            offlinePlayer = GetOfflinePlayer(citizenid)
            if not offlinePlayer then
                lib.notify(source, {
                    title = 'Error',
                    description = 'Player not found with citizen ID: ' .. citizenid,
                    type = 'error'
                })
                return nil
            end
        end
        
        local playerData = targetPlayer and targetPlayer.PlayerData or offlinePlayer.PlayerData
        local creditData = GetOrCreateCreditScore(citizenid)
        local creditHistory = GetCreditHistory(citizenid, 50)
        
        local bankBalance = 0
        if targetPlayer then
            bankBalance = targetPlayer.PlayerData.money.bank or 0
        else
            bankBalance = (playerData.money and playerData.money.bank) or 0
            if bankBalance == 0 and Config.Framework ~= 'esx' then
                local moneyData = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', { citizenid })
                if moneyData and moneyData.money then
                    local money = type(moneyData.money) == 'string' and json.decode(moneyData.money) or moneyData.money
                    bankBalance = money.bank or 0
                end
            end
        end
        bankBalance = math.floor(tonumber(bankBalance) or 0)
        
        local jobName = 'Unknown'
        local jobGradeName = 'Unknown'
        if playerData.job then
            jobName = playerData.job.label or playerData.job.name or 'Unknown'
            if playerData.job.grade and playerData.job.grade.name then
                jobGradeName = playerData.job.grade.name
            end
        end
        
        return {
            citizenid = citizenid,
            idLabel = idLabel,
            firstname = playerData.charinfo.firstname or 'Unknown',
            lastname = playerData.charinfo.lastname or 'Unknown',
            birthdate = playerData.charinfo.birthdate or 'Unknown',
            jobName = jobName,
            jobGradeName = jobGradeName,
            bankBalance = bankBalance,
            creditScore = creditData.score,
            creditHistory = creditHistory
        }
    end)

    local idLabelParam = (Config.Framework == 'esx') and 'SSN' or 'Citizen ID'
    lib.addCommand('creditreport', {
        help = 'Run a credit report for a player',
        params = {
            {
                name = 'citizenid',
                type = 'string',
                help = idLabelParam .. ' of the player (optional - will prompt if not provided)',
                required = false
            }
        }
    }, HandleCreditReportCommand)
    
    if Config.EnableCreditCommands then
        lib.addCommand('addcredit', {
            help = 'Add credit score to a player',
            params = {
                {
                    name = 'citizenid',
                    type = 'string',
                    help = 'Citizen ID of the player',
                    required = true
                },
                {
                    name = 'amount',
                    type = 'number',
                    help = 'Amount of credit to add',
                    required = true
                },
                {
                    name = 'description',
                    type = 'string',
                    help = 'Description for the credit change (optional)',
                    required = false
                }
            }
        }, HandleAddCreditCommand)
        
        lib.addCommand('reducecredit', {
            help = 'Reduce credit score from a player',
            params = {
                {
                    name = 'citizenid',
                    type = 'string',
                    help = 'Citizen ID of the player',
                    required = true
                },
                {
                    name = 'amount',
                    type = 'number',
                    help = 'Amount of credit to reduce',
                    required = true
                },
                {
                    name = 'description',
                    type = 'string',
                    help = 'Description for the credit change (optional)',
                    required = false
                }
            }
        }, HandleReduceCreditCommand)
    end
end)

-- Export: Get Credit Score
exports('GetCredit', function(citizenid)
    if not citizenid then
        return nil
    end
    return GetCreditScore(citizenid)
end)

-- Export: Get Credit Score (lowercase alias)
exports('getcredit', function(citizenid)
    if not citizenid then
        return nil
    end
    return GetCreditScore(citizenid)
end)

-- Export: Add Credit Score
exports('AddCredit', function(citizenid, amount, description)
    if not citizenid or not amount then
        return false
    end
    return AddCreditScore(citizenid, amount, description)
end)

-- Export: Reduce Credit Score
exports('ReduceCredit', function(citizenid, amount, description)
    if not citizenid or not amount then
        return false
    end
    return ReduceCreditScore(citizenid, amount, description)
end)
