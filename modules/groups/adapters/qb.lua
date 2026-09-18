TSS.Groups.RegisterAdapter('qb', TSS.Resources.QBCore, {
    supports = {
        bossroles = true, jobs = true, gangs = true,
        jobboss = true, gangboss = true,
    },
    bossRoles = function(_, role)
        local roles = TSS.Groups.Utils.FindBossRole(TSS.Framework.Jobs(), role)
        if next(roles) then return roles end
        return TSS.Groups.Utils.FindBossRole(TSS.Framework.Gangs(), role)
    end,
    isJobBoss = function(_, role, source)
        local data = TSS.Framework.PlayerData(source) or {}
        local job = data.job or {}
        if role and job.name ~= role then return false end
        if job.isboss == true or job.isBoss == true then return true end

        local grade = type(job.grade) == 'table' and (job.grade.level or job.grade.grade) or job.grade
        local definition = TSS.Framework.Jobs()[job.name or role]
        local gradeData = definition and definition.grades and definition.grades[tostring(grade)]
        return gradeData and (gradeData.isboss == true or gradeData.isBoss == true or gradeData.bankAuth == true) or false
    end,
    isGangBoss = function(_, role, source)
        local data = TSS.Framework.PlayerData(source) or {}
        local gang = data.gang or {}
        if role and gang.name ~= role then return false end
        if gang.isboss == true or gang.isBoss == true then return true end

        local grade = type(gang.grade) == 'table' and (gang.grade.level or gang.grade.grade) or gang.grade
        local definition = TSS.Framework.Gangs()[gang.name or role]
        local gradeData = definition and definition.grades and definition.grades[tostring(grade)]
        return gradeData and (gradeData.isboss == true or gradeData.isBoss == true or gradeData.bankAuth == true) or false
    end,
}, { priority = 20, aliases = { 'qb-core', 'qbcore' } })

TSS.Groups.RegisterManagementAdapter('qb', TSS.Resources.QbManagement, {
    supports = { management = true, jobs = true, gangs = true },
    openBossMenu = function()
        TriggerEvent('qb-bossmenu:client:OpenMenu')
        return true
    end,
    openGangMenu = function()
        TriggerEvent('qb-gangmenu:client:OpenMenu')
        return true
    end,
}, { priority = 20, aliases = { 'qb-management' } })
