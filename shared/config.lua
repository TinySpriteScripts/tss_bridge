TSS = TSS or {}
TSS.Config = TSS.Config or {}

TSS.Config.BridgeLabUsers = { --can use discord or fivem identifier
    {name = "Sayer", discord = '456353189525061632', fivem = 'fivem:2866947'},
    {name = "McKlean", discord = '105648977088684032'},
}

TSS.Config.Debug = TSS.Config.Debug or GetConvar('tss_debug', 'false') == 'true'
TSS.Config.Framework = GetConvar('tss_framework', TSS.Config.Framework or 'auto')
TSS.Config.Notify = GetConvar('tss_notify', TSS.Config.Notify or 'auto')
TSS.Config.ProgressBar = GetConvar('tss_progressbar', TSS.Config.ProgressBar or 'auto')
TSS.Config.Target = GetConvar('tss_target', TSS.Config.Target or 'auto')
TSS.Config.Inventory = GetConvar('tss_inventory', TSS.Config.Inventory or 'auto')
TSS.Config.TextUI = GetConvar('tss_textui', TSS.Config.TextUI or 'auto')
TSS.Config.Interaction = GetConvar('tss_interaction', TSS.Config.Interaction or 'auto')
TSS.Config.VehicleKeys = GetConvar('tss_vehiclekeys', TSS.Config.VehicleKeys or 'auto')
TSS.Config.Fuel = GetConvar('tss_fuel', TSS.Config.Fuel or 'auto')
TSS.Config.Locale = GetConvar('tss_locale', TSS.Config.Locale or 'en')
TSS.Config.CallbackTimeout = tonumber(GetConvar('tss_callback_timeout', tostring(TSS.Config.CallbackTimeout or 10000))) or 10000
TSS.Config.CallbackTimeout = math.max(1000, math.min(120000, TSS.Config.CallbackTimeout))
TSS.Config.DebugPrints = TSS.Config.Debug
TSS.Config.DebugPolyzones = TSS.Config.Debug
TSS.Config.DebugTools = TSS.Config.Debug
TSS.Config.FadeEntities = TSS.Config.FadeEntities ~= false

TSS.Resources = {
    OxLib = 'ox_lib',
    QBCore = 'qb-core',
    Qbox = 'qbx_core',
    ESX = 'es_extended',
    -- Notifications
    OkokNotify = 'okokNotify',
    MythicNotify = 'mythic_notify',
    WasabiNotify = 'wasabi_notify',
    -- Progressbars
    ProgressBar = 'progressbar',
    -- Targets
    OxTarget = 'ox_target',
    QbTarget = 'qb-target',
    TgiannTarget = 'tgiann-target',
    BtTarget = 'bt-target',
    -- Vehicle keys
    QbVehicleKeys = 'qb-vehiclekeys',
    QboxVehicleKeys = 'qbx_vehiclekeys',
    -- Fuel
    LegacyFuel = 'LegacyFuel',
    OxFuel = 'ox_fuel',
    PsFuel = 'ps-fuel',
    CdnFuel = 'cdn-fuel',
    -- Inventories
    OxInventory = 'ox_inventory',
    QbInventory = 'qb-inventory',
    PsInventory = 'ps-inventory',
    LjInventory = 'lj-inventory',
    QsInventory = 'qs-inventory',
    CoreInventory = 'core_inventory',
    CodemInventory = 'codem-inventory',
    OrigenInventory = 'origen_inventory',
    TgiannInventory = 'tgiann-inventory',
    Ak47Inventory = 'ak47_inventory',
    MfInventory = 'mf-inventory',
    TssInventory = 'tss-inventory',
    ChezzaInventory = 'inventory',
}
