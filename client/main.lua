CreateThread(function()
    -- Wait for ox_lib resource to be started
    while GetResourceState('ox_lib') ~= 'started' do
        Wait(100)
    end
    
    local attempts = 0
    while not lib do
        Wait(100)
        attempts = attempts + 1
        if attempts > 100 then -- 10 seconds
            return
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)

local function FormatCurrency(amount)
    return '$' .. string.format("%.2f", amount)
end

local function FormatDate(dateString)
    if not dateString or dateString == 'Unknown' then
        return 'Unknown'
    end
    if type(dateString) == 'string' and dateString:match('^%d+%-%d+%-%d+') then
        return dateString
    end
    return dateString
end

local function GetCreditScoreColor(score)
    if score >= 750 then
        return 'green'
    elseif score >= 700 then
        return 'lightgreen'
    elseif score >= 650 then
        return 'yellow'
    elseif score >= 600 then
        return 'orange'
    else
        return 'red'
    end
end

local function GetCreditStatus(score)
    if score >= 750 then
        return 'Excellent'
    elseif score >= 700 then
        return 'Very Good'
    elseif score >= 650 then
        return 'Good'
    elseif score >= 600 then
        return 'Fair'
    else
        return 'Poor'
    end
end

local function ShowCreditHistory(history)
    if not history or #history == 0 then
        lib.notify({
            title = 'Credit History',
            description = 'No credit history available.',
            type = 'inform'
        })
        return
    end
    
    local options = {}
    
    options[#options + 1] = {
        title = 'Back to Report',
        icon = 'arrow-left',
        onSelect = function()
            lib.hideContext()
        end
    }
    
    for i, entry in ipairs(history) do
        local changeAmount = tonumber(entry.change_amount) or 0
        local changeText = changeAmount > 0 and '+' .. changeAmount or tostring(changeAmount)
        local changeColorScheme = changeAmount > 0 and 'green' or 'red'
        local dateStr = FormatDate(entry.created_at)
        
        options[#options + 1] = {
            title = changeText .. ' Points',
            description = entry.description or 'No description',
            icon = changeAmount > 0 and 'arrow-up' or 'arrow-down',
            iconColor = changeAmount > 0 and '#22c55e' or '#ef4444', -- Green for positive, red for negative
            metadata = {
                { label = 'Date', value = dateStr },
                { label = 'Change', value = changeText, colorScheme = changeColorScheme }
            },
            disabled = true
        }
    end
    
    lib.registerContext({
        id = 'credit_report_history',
        title = 'Credit History (' .. #history .. ' entries)',
        options = options
    })
    
    lib.showContext('credit_report_history')
end

local function ShowPersonalInfo(reportData)
    local options = {
        {
            title = 'First Name',
            description = reportData.firstname,
            icon = 'user',
            disabled = true
        },
        {
            title = 'Last Name',
            description = reportData.lastname,
            icon = 'user',
            disabled = true
        },
        {
            title = 'Date of Birth',
            description = FormatDate(reportData.birthdate),
            icon = 'calendar',
            disabled = true
        },
        {
            title = 'Citizen ID',
            description = reportData.citizenid,
            icon = 'id-card',
            disabled = true
        },
        {
            title = 'Back',
            icon = 'arrow-left',
            onSelect = function()
                ShowCreditReport(reportData)
            end
        }
    }
    
    lib.registerContext({
        id = 'credit_report_personal',
        title = 'Personal Information',
        menu = 'credit_report_main',
        options = options
    })
    
    lib.showContext('credit_report_personal')
end

local function ShowCreditReport(reportData)
    if not reportData then
        lib.notify({
            title = 'Error',
            description = 'Failed to retrieve credit report.',
            type = 'error'
        })
        return
    end
    
    -- Send data to NUI
    SendNUIMessage({
        action = 'open',
        report = reportData
    })
    
    -- Enable NUI focus
    SetNuiFocus(true, true)
end

RegisterNetEvent('bs_credit:client:openCreditReport', function(citizenid)
    -- Wait for lib to be available (should already be available, but double-check)
    if not lib then
        local libWaitCount = 0
        while not lib do
            Wait(100)
            libWaitCount = libWaitCount + 1
            if libWaitCount > 50 then
                return
            end
        end
    end
    
    if not citizenid or citizenid == '' then
        local idLabel = Config.Framework == 'esx' and 'SSN' or 'Citizen ID'
        local idPlaceholder = Config.Framework == 'esx' and 'XXX-XX-XXXX' or 'ABC12345'
        local input = lib.inputDialog('Credit Report', {
            {
                type = 'input',
                label = idLabel,
                description = 'Enter the ' .. idLabel:lower() .. ' to lookup',
                required = true,
                placeholder = idPlaceholder
            }
        })
        
        if not input or not input[1] or input[1] == '' then
            return
        end
        
        citizenid = input[1]
    end
    
    local success, reportData = pcall(function()
        return lib.callback.await('bs_credit:server:getCreditReport', false, citizenid)
    end)
    
    if not success then
        lib.notify({
            title = 'Error',
            description = 'Failed to retrieve credit report: ' .. tostring(reportData),
            type = 'error'
        })
        return
    end
    
    if reportData then
        lib.notify({
            title = 'Credit Report',
            description = 'Loading credit report for ' .. reportData.firstname .. ' ' .. reportData.lastname,
            type = 'success'
        })
        
        ShowCreditReport(reportData)
    else
        lib.notify({
            title = 'Error',
            description = 'Failed to retrieve credit report. Player may not exist.',
            type = 'error'
        })
    end
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
