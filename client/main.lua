-- Wait for ox_lib to be available
CreateThread(function()
    -- Wait for ox_lib resource to be started
    while GetResourceState('ox_lib') ~= 'started' do
        Wait(100)
    end
    
    -- Wait for lib to be available
    local attempts = 0
    while not lib do
        Wait(100)
        attempts = attempts + 1
        if attempts > 100 then -- 10 seconds
            return
        end
    end
end)

-- Function to format currency
local function FormatCurrency(amount)
    return '$' .. string.format("%.2f", amount)
end

-- Function to format date
local function FormatDate(dateString)
    if not dateString or dateString == 'Unknown' then
        return 'Unknown'
    end
    -- If it's a timestamp string, try to format it
    if type(dateString) == 'string' and dateString:match('^%d+%-%d+%-%d+') then
        return dateString
    end
    return dateString
end

-- Function to get credit score color
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

-- Function to get credit status text
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

-- Function to show credit history
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
    
    -- Add back button first
    options[#options + 1] = {
        title = 'Back to Report',
        icon = 'arrow-left',
        onSelect = function()
            lib.hideContext()
        end
    }
    
    -- Add history entries (most recent first)
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

-- Function to show personal information
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

-- Function to display credit report using NUI
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

-- Event to open credit report
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
        -- Ask for citizenid if not provided
        local input = lib.inputDialog('Credit Report', {
            {
                type = 'input',
                label = 'Citizen ID',
                description = 'Enter the citizen ID to lookup',
                required = true,
                placeholder = 'ABC12345'
            }
        })
        
        if not input or not input[1] or input[1] == '' then
            return
        end
        
        citizenid = input[1]
    end
    
    -- Get credit report from server
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

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
