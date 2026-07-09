TSS = TSS or {}
TSS.Config = TSS.Config or {}

TSS.Config.Debug = TSS.Config.Debug or GetConvar('tss_debug', 'false') == 'true'
TSS.Config.ProgressBar = GetConvar('tss_progressbar', TSS.Config.ProgressBar or 'auto')
TSS.Config.Target = GetConvar('tss_target', TSS.Config.Target or 'auto')
TSS.Config.Inventory = GetConvar('tss_inventory', TSS.Config.Inventory or 'auto')
TSS.Config.DebugPrints = TSS.Config.Debug
TSS.Config.DebugPolyzones = TSS.Config.Debug
TSS.Config.DebugTools = TSS.Config.Debug
TSS.Config.FadeEntities = TSS.Config.FadeEntities ~= false

TSS.Resources = {
    OxLib = 'ox_lib',
    QBCore = 'qb-core',
    -- Progressbars
    ProgressBar = 'progressbar',
    -- Targets
    OxTarget = 'ox_target',
    QbTarget = 'qb-target',
    TgiannTarget = 'tgiann-target',
    BtTarget = 'bt-target',
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
