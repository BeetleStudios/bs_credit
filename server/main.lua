-- Command handler function (defined early so RegisterCommand can use it)
local function HandleCreditReportCommand(source, args, rawCommand)
    print('^3[ns-credit]^7 Command executed by source: ' .. source)
    
    local player = exports.qbx_core:GetPlayer(source)
    if not player then 
        print('^1[ns-credit]^7 Error: Player not found for source: ' .. source)
        return 
    end
    
    -- Job check removed for testing
    -- local playerJob = player.PlayerData.job
    -- print('^3[ns-credit]^7 Player job: ' .. (playerJob and playerJob.name or 'nil') .. ', Required: ' .. Config.BankerJob)
    -- 
    -- if not playerJob or playerJob.name ~= Config.BankerJob then
    --     lib.notify(source, {
    --         title = 'Access Denied',
    --         description = 'You must be a banker to use this command. Your job: ' .. (playerJob and playerJob.name or 'none'),
    --         type = 'error'
    --     })
    --     return
    -- end
    
    print('^2[ns-credit]^7 Access granted, triggering client event')
    
    -- Parse citizenid from args (support both formats)
    local citizenid = nil
    if args and type(args) == 'table' then
        print('^3[ns-credit]^7 Args table: ' .. json.encode(args))
        if args.citizenid then
            citizenid = args.citizenid
        elseif args[1] then
            citizenid = args[1]
        end
    end
    
    print('^3[ns-credit]^7 Parsed citizenid: ' .. (citizenid or 'nil'))
    print('^3[ns-credit]^7 Triggering client event to source: ' .. source)
    
    -- If citizenid provided, use it; otherwise client will prompt
    TriggerClientEvent('ns-credit:client:openCreditReport', source, citizenid)
    
    print('^2[ns-credit]^7 Client event triggered')
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

-- Command handler for adding credit
local function HandleAddCreditCommand(source, args, rawCommand)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then 
        return 
    end
    
    -- Parse arguments
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

-- Command handler for reducing credit
local function HandleReduceCreditCommand(source, args, rawCommand)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then 
        return 
    end
    
    -- Parse arguments
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

-- Register commands immediately using RegisterCommand (doesn't need lib)
RegisterCommand('creditreport', HandleCreditReportCommand, false)
RegisterCommand('addcredit', HandleAddCreditCommand, false)
RegisterCommand('reducecredit', HandleReduceCreditCommand, false)
print('^2[ns-credit]^7 Commands registered via RegisterCommand')

-- Wait for lib to be available
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

    -- Get full credit report (for UI)
    lib.callback.register('ns-credit:server:getCreditReport', function(source, citizenid)
        print('^3[ns-credit]^7 Callback received from source: ' .. source .. ', citizenid: ' .. (citizenid or 'nil'))
        
        if not citizenid or citizenid == '' then
            print('^1[ns-credit]^7 Error: No citizenid provided')
            lib.notify(source, {
                title = 'Error',
                description = 'No citizen ID provided.',
                type = 'error'
            })
            return nil
        end
        
        local player = exports.qbx_core:GetPlayer(source)
        if not player then
            print('^1[ns-credit]^7 Error: Player not found for source: ' .. source)
            return nil
        end
        
        -- Job check removed for testing
        -- local playerJob = player.PlayerData.job
        -- if not playerJob or playerJob.name ~= Config.BankerJob then
        --     lib.notify(source, {
        --         title = 'Access Denied',
        --         description = 'You must be a banker to access credit reports.',
        --         type = 'error'
        --     })
        --     return nil
        -- end
        
        print('^3[ns-credit]^7 Looking up player with citizenid: ' .. citizenid)
        
        -- Get player data by citizenid
        local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(citizenid)
        local offlinePlayer = nil
        
        if not targetPlayer then
            print('^3[ns-credit]^7 Player not online, trying offline player')
            -- Try to get offline player
            offlinePlayer = exports.qbx_core:GetOfflinePlayer(citizenid)
            if not offlinePlayer then
                print('^1[ns-credit]^7 Error: Player not found (online or offline)')
                lib.notify(source, {
                    title = 'Error',
                    description = 'Player not found with citizen ID: ' .. citizenid,
                    type = 'error'
                })
                return nil
            end
            print('^2[ns-credit]^7 Found offline player')
        else
            print('^2[ns-credit]^7 Found online player')
        end
        
        local playerData = targetPlayer and targetPlayer.PlayerData or offlinePlayer.PlayerData
        print('^3[ns-credit]^7 Getting credit data for: ' .. citizenid)
        local creditData = GetOrCreateCreditScore(citizenid)
        local creditHistory = GetCreditHistory(citizenid, 50)
        
        -- Get bank balance
        local bankBalance = 0
        if targetPlayer then
            bankBalance = targetPlayer.PlayerData.money.bank or 0
        else
            -- For offline players, get from database
            local moneyData = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', { citizenid })
            if moneyData and moneyData.money then
                local money = type(moneyData.money) == 'string' and json.decode(moneyData.money) or moneyData.money
                bankBalance = money.bank or 0
            end
        end
        
        -- Get job information
        local jobName = 'Unknown'
        local jobGradeName = 'Unknown'
        if playerData.job then
            jobName = playerData.job.label or playerData.job.name or 'Unknown'
            if playerData.job.grade and playerData.job.grade.name then
                jobGradeName = playerData.job.grade.name
            end
        end
        
        print('^2[ns-credit]^7 Returning credit report data')
        return {
            citizenid = citizenid,
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

    -- Also register using lib.addCommand (for better integration and chat suggestions)
    lib.addCommand('creditreport', {
        help = 'Run a credit report for a player',
        params = {
            {
                name = 'citizenid',
                type = 'string',
                help = 'Citizen ID of the player (optional - will prompt if not provided)',
                required = false
            }
        }
    }, HandleCreditReportCommand)
    
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
    
    print('^2[ns-credit]^7 All commands also registered via lib.addCommand')
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
