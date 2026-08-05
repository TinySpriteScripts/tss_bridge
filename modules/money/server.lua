TSSModuleLoader.Define({
    name = 'Money',
    dependencies = { 'Framework' },
    files = { 'modules/money/shared.lua' },
    server = function(context)
        ---@type TSSMoneyServerModule
        local Money = context.CopyFunctions(TSS.Money, { 'Balance', 'Has' })

        local function normalizeType(moneyType)
            moneyType = tostring(moneyType or 'cash'):lower()
            return moneyType == 'money' and 'cash' or moneyType
        end

        local function validAmount(amount, allowZero)
            amount = tonumber(amount)
            if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then return nil end
            if allowZero and amount < 0 or not allowZero and amount <= 0 then return nil end
            return amount
        end

        local function mutate(action, source, moneyType, amount, reason)
            if type(source) ~= 'number' then return false end
            amount = validAmount(amount, action == 'Set')
            if not amount then return false end
            moneyType = normalizeType(moneyType)
            reason = type(reason) == 'string' and reason:sub(1, 128) or 'tss_bridge'

            local system, resource = TSS.Framework.System()
            if system == 'qbox' then
                local ok, result = TSS.CallExport(resource, action .. 'Money', source, moneyType, amount, reason)
                return ok and result == true
            end

            local player = TSS.Framework.Player(source)
            if not player then return false end

            if system == 'qb' then
                local fn = player.Functions and player.Functions[action .. 'Money']
                return type(fn) == 'function' and fn(moneyType, amount, reason) == true or false
            end

            local account = moneyType == 'cash' and 'money' or moneyType
            local fn
            if action == 'Add' then fn = account == 'money' and player.addMoney or player.addAccountMoney end
            if action == 'Remove' then fn = account == 'money' and player.removeMoney or player.removeAccountMoney end
            if action == 'Set' then fn = account == 'money' and player.setMoney or player.setAccountMoney end
            if type(fn) ~= 'function' then return false end

            local ok = pcall(fn, account == 'money' and amount or account,
                account == 'money' and reason or amount, account == 'money' and nil or reason)
            return ok
        end

        --- Adds money to a player after validating the amount.
        ---@param source integer Server player ID.
        ---@param moneyType TSSMoneyType Account type.
        ---@param amount number Positive amount to add.
        ---@param reason? string Audit reason.
        ---@return boolean success
        function Money.Add(source, moneyType, amount, reason)
            return mutate('Add', source, moneyType, amount, reason)
        end

        --- Removes money from a player after validating the amount.
        ---@param source integer Server player ID.
        ---@param moneyType TSSMoneyType Account type.
        ---@param amount number Positive amount to remove.
        ---@param reason? string Audit reason.
        ---@return boolean success
        function Money.Remove(source, moneyType, amount, reason)
            return mutate('Remove', source, moneyType, amount, reason)
        end

        --- Sets a player's account balance.
        ---@param source integer Server player ID.
        ---@param moneyType TSSMoneyType Account type.
        ---@param amount number Non-negative balance.
        ---@param reason? string Audit reason.
        ---@return boolean success
        function Money.Set(source, moneyType, amount, reason)
            return mutate('Set', source, moneyType, amount, reason)
        end

        return Money
    end,
})
