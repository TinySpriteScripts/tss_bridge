-- Loaded last in each realm so consumers cannot call GetModules against a
-- partially registered module catalog during resource startup.
TSSModuleLoader.RegisterExport()
