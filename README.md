# ns-credit - Qbox FiveM Script

A comprehensive credit score system for FiveM servers that allows bankers to view player credit reports and manage credit scores.

## Features

- **Credit Reports**: Bankers can view detailed credit reports for any player including personal information, bank balance, and credit score
- **Credit Score Meter**: Visual representation of credit score with color-coded ranges (Very Poor to Excellent)
- **Credit History**: Complete transaction history showing all credit score increases and decreases with descriptions
- **Automatic Score Creation**: New players automatically receive a base credit score when first checked
- **Credit Management**: Optional commands to add or reduce credit scores with custom descriptions
- **Job-Based Access**: Restrict credit report access to specific job (banker)
- **Export Functions**: Exportable functions for other scripts to interact with the credit system

## Dependencies

1. qbox (qbx_core)
2. oxmysql
3. ox_lib

## Usage

1. **Viewing Credit Reports**: Bankers can use `/creditreport [citizenid]` to view a player's credit report
2. **Credit Report UI**: Opens a detailed NUI showing:
   - Personal information (name, date of birth, job)
   - Current bank balance
   - Credit score with visual meter
   - Complete credit history with dates and descriptions
3. **Managing Credit Scores** (if enabled): Use `/addcredit [citizenid] [amount] [description]` or `/reducecredit [citizenid] [amount] [description]` to adjust scores

## Installation

1. Ensure ns-credit is in your `[standalone]` folder
2. Run the SQL script located in `sql.sql` to create the necessary tables
3. Configure `Config.BankerJob` in `config.lua` to match your banker job name
4. Set `Config.EnableCreditCommands` to `true` in `config.lua` if you want to enable the addcredit/reducecredit commands
5. Logo can be swapped out with same name in `html/logo.png`

## Configuration

Edit `config.lua` to customize:
- `Config.BaseCreditScore`: Default credit score for new players (default: 650)
- `Config.BankerJob`: Job name required to access credit reports (default: 'banker')
- `Config.MinCreditScore`: Minimum credit score value (default: 300)
- `Config.MaxCreditScore`: Maximum credit score value (default: 850)
- `Config.EnableCreditCommands`: Enable/disable addcredit and reducecredit commands (default: false)

## Exports

- `exports['ns-credit']:GetCredit(citizenid)` - Returns the credit score for a citizenid
- `exports['ns-credit']:getcredit(citizenid)` - Lowercase alias for GetCredit
- `exports['ns-credit']:AddCredit(citizenid, amount, description)` - Adds credit score to a player
- `exports['ns-credit']:ReduceCredit(citizenid, amount, description)` - Reduces credit score from a player

## Support

For support, questions, or bug reports, please join our Discord server:

[Discord Support Server](https://discord.gg/xSCBAYFwmY)
