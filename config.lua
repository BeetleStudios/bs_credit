Config = {}

-- Framework: 'qbx_core' (Qbox), 'qb-core' (QBCore), or 'esx' (ESX Legacy)
Config.Framework = 'qb-core'

-- Base credit score for new players
Config.BaseCreditScore = 650

-- Job(s) that can access credit reports (single string or list of job names)
Config.BankerJob = { 'banker', 'cardealer' }

-- Minimum credit score
Config.MinCreditScore = 300

-- Maximum credit score
Config.MaxCreditScore = 850

-- Enable/disable addcredit and reducecredit commands
-- Set to true to enable these commands, false to disable
Config.EnableCreditCommands = true
