---@meta

-- This file is intentionally documentation-only. LuaLS indexes it to provide
-- completion and parameter help for tables returned by the GetModules export.

---@alias TSSFrameworkName 'qb'|'qbox'|'esx'
---@alias TSSNotifyType 'inform'|'success'|'warning'|'error'
---@alias TSSMoneyType 'cash'|'bank'|'crypto'|string
---@alias TSSEntity number

---@class TSSModuleOptions
---@field Target? string Target provider for this resource.
---@field Notify? string Notification provider for this resource.
---@field ProgressBar? string Progress provider for this resource.
---@field TextUI? string Text UI provider for this resource.
---@field Interaction? string Interaction mode for this resource (target/textui/auto).

---@class TSSModuleContext
---@field Caller string Resource that requested the module.
---@field Options TSSModuleOptions Options supplied to `GetModules`.
---@field Preference fun(key: string, preferred?: string): string? Returns the per-call or resource preference.
---@field ProviderAPI fun(source: table, key: string): table Builds scoped System and Supports functions.
---@field ProviderData fun(key: string, data?: table|string): table Copies display data with the resource preference.
---@field Realm 'client'|'server' Current runtime realm.
---@field CopyFunctions fun(source: table, names: string[]): table Copies named functions into a new public API table.
---@field OnStop fun(callback: fun()) Registers caller-scoped cleanup.

---@class TSSModuleDefinition
---@field name string Canonical module name returned by `GetModules`.
---@field dependencies? string[] Modules whose implementation files must initialize first.
---@field files? string[] Implementation files loaded lazily in both realms.
---@field clientFiles? string[] Additional files loaded only by the client definition.
---@field serverFiles? string[] Additional files loaded only by the server definition.
---@field client? fun(context: TSSModuleContext): table<string, function> Client public-API factory. Omit for server-only modules.
---@field server? fun(context: TSSModuleContext): table<string, function> Server public-API factory. Omit for client-only modules.

---@class TSSNotifyData
---@field title? string Notification heading.
---@field description? string Notification body.
---@field message? string Alias for `description`.
---@field type? TSSNotifyType Notification style.
---@field duration? integer Display duration in milliseconds.
---@field position? string Screen position when supported by the selected adapter.
---@field icon? string Icon name when supported by the selected adapter.
---@field id? string Replacement/deduplication identifier when supported.

---@class TSSTextUIData
---@field text string Text displayed to the player.
---@field position? string Screen position when supported.
---@field icon? string Icon name when supported.

---@class TSSProgressData
---@field label string Text displayed while progress is active.
---@field duration integer Duration in milliseconds.
---@field canCancel? boolean Whether the player may cancel.
---@field useWhileDead? boolean Whether progress may run while dead.
---@field controlDisables? table Controls disabled while progress is active.
---@field animation? table Animation configuration.
---@field prop? table Prop configuration.

---@class TSSStashData
---@field id string Unique stash identifier.
---@field label? string Display label.
---@field slots? integer Slot count.
---@field weight? integer Maximum weight.
---@field owner? string|number|boolean Owner passed to the inventory adapter.
---@field groups? table<string, integer> Allowed groups and minimum grades.
---@field coords? vector3|table Access coordinates.

---@class TSSTargetOption
---@field label string Display label.
---@field icon? string Display icon.
---@field name? string Unique option name.
---@field event? string Event triggered on selection.
---@field serverEvent? string Server event triggered on selection.
---@field command? string Command executed on selection.
---@field action? fun(entity: TSSEntity, data: table) Direct selection handler.
---@field canInteract? fun(entity: TSSEntity, distance: number, coords: vector3|table, name?: string, bone?: integer): boolean
---@field job? string|string[]|table<string, integer>
---@field gang? string|string[]|table<string, integer>
---@field item? string|string[]|table<string, integer>
---@field distance? number Interaction distance.

---@class TSSTargetZoneData
---@field name? string Unique zone name.
---@field coords vector3|table Zone centre.
---@field size? vector3|table Box dimensions.
---@field radius? number Circle radius.
---@field rotation? number Box heading.
---@field debug? boolean Draw the zone while developing.

---@class TSSInteractionData
---@field id? string Unique interaction identifier.
---@field coords vector3|table Interaction centre.
---@field distance? number Activation distance.
---@field interactDistance? number Selection distance.
---@field label string Prompt or target label.
---@field icon? string Target icon.
---@field onSelect fun(data?: table) Selection handler.
---@field canInteract? fun(): boolean
---@field job? string|string[]|table<string, integer>
---@field gang? string|string[]|table<string, integer>
---@field item? string|string[]|table<string, integer>

---@class TSSBlipData
---@field coords? vector3|table Blip coordinates (required for coordinate creation; optional on update).
---@field pos? vector3|table Alias of coords.
---@field entity? integer Entity to attach a new blip to.
---@field sprite? integer Sprite ID.
---@field color? integer Colour ID.
---@field colour? integer Alias of color.
---@field col? integer Alias of color.
---@field scale? number Display scale.
---@field name? string Map label.
---@field label? string Alias of name.
---@field shortRange? boolean Whether the blip is only visible nearby.
---@field display? integer Display mode, including 0 to hide.
---@field disp? integer Alias of display.
---@field category? integer Legend category.
---@field hiddenOnLegend? boolean Hide the blip from the map legend.
---@field route? boolean Enable or disable a GPS route.
---@field routeColor? integer GPS route colour ID.

---@class TSSEntityCreateData
---@field model string|integer Model name or hash.
---@field coords? vector3|vector4|table Spawn coordinates.
---@field heading? number Spawn heading.

---@class TSSEntityCreateOptions
---@field networked? boolean Create a networked entity.
---@field freeze? boolean Freeze the entity after creation.
---@field invincible? boolean Make the entity invincible.
---@field fade? boolean Fade the entity in.
---@field scenario? string Scenario started on a ped.
---@field anim? table Animation started on a ped.

---@class TSSDistanceController
---@field getEntity fun(): TSSEntity|nil Returns the currently spawned entity.
---@field remove fun() Stops the controller and deletes its entity.

---@class TSSFrameworkModule
---@field System fun(): system?: TSSFrameworkName, resource?: string
---@field Object fun(): table|nil
---@field Player fun(source?: integer): table|nil
---@field PlayerData fun(source?: integer): table|nil
---@field Jobs fun(): table
---@field Gangs fun(): table
---@field Supports fun(feature: string): boolean

---@class TSSPlayerClientModule
---@field Data fun(): table|nil
---@field Identifier fun(kind?: string): string|nil
---@field Name fun(): string|nil
---@field Job fun(): table|nil
---@field Gang fun(): table|nil
---@field Metadata fun(key?: string): any
---@field HasGroup fun(filter: string|string[]|table<string, integer>): boolean
---@field IsLoaded fun(): boolean

---@class TSSPlayerServerModule
---@field Data fun(source: integer): table|nil
---@field Identifier fun(source: integer, kind?: string): string|nil
---@field Name fun(source: integer): string|nil
---@field Job fun(source: integer): table|nil
---@field Gang fun(source: integer): table|nil
---@field Metadata fun(source: integer, key?: string): any
---@field HasGroup fun(source: integer, filter: string|string[]|table<string, integer>): boolean
---@field IsLoaded fun(source: integer): boolean
---@field HasPermission fun(source: integer, permission: string|string[]): boolean

---@class TSSBankingClientModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string, preferred?: string): boolean
---@field GetAccount fun(accountType?: TSSMoneyType): number

---@class TSSBankingServerModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string, preferred?: string): boolean
---@field GetAccount fun(source: integer, accountType?: TSSMoneyType): number
---@field AddMoney fun(source: integer, accountType: TSSMoneyType, amount: number, reason?: string): boolean
---@field RemoveMoney fun(source: integer, accountType: TSSMoneyType, amount: number, reason?: string): boolean
---@field GetSociety fun(society: string, kind?: 'job'|'gang', preferred?: string): number
---@field ChargeSociety fun(society: string, amount: number, kind?: 'job'|'gang', reason?: string, preferred?: string): boolean
---@field FundSociety fun(society: string, amount: number, kind?: 'job'|'gang', reason?: string, preferred?: string): boolean

---@class TSSBillingModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string, preferred?: string): boolean
---@field Open fun(data: table, preferred?: string): boolean

---@class TSSNotifyModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string, preferred?: string): boolean
---@field Send fun(first: integer|TSSNotifyData|string, second?: TSSNotifyData|string, third?: TSSNotifyType, fourth?: integer, fifth?: integer): boolean Use `Send(data)` on the client or `Send(source, data)` on the server; legacy positional arguments are also accepted.

---@class TSSTextUIClientModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string, preferred?: string): boolean
---@field Show fun(data: TSSTextUIData|string): boolean
---@field Hide fun(): boolean
---@field IsOpen fun(): isOpen: boolean, data?: TSSTextUIData

---@class TSSTextUIServerModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string, preferred?: string): boolean
---@field Show fun(source: integer, data: TSSTextUIData|string): boolean
---@field Hide fun(source: integer): boolean

---@class TSSCallbacksClientModule
---@field Register fun(name: string, handler: fun(...): ...): boolean
---@field Unregister fun(name: string): boolean
---@field Await fun(name: string, timeout?: integer, ...): ...
---@field Trigger fun(name: string, callback: fun(...), ...): boolean

---@class TSSCallbacksServerModule
---@field Register fun(name: string, handler: fun(source: integer, ...): ...): boolean
---@field Unregister fun(name: string): boolean
---@field Await fun(source: integer, name: string, timeout?: integer, ...): ...
---@field Trigger fun(source: integer, name: string, callback: fun(...), ...): boolean

---@class TSSInventoryClientModule
---@field System fun(): system?: string, resource?: string
---@field Supports fun(feature: string): boolean
---@field Count fun(item: string, metadata?: table|string): integer
---@field Has fun(item: string, amount?: integer, metadata?: table|string): boolean
---@field Player fun(): table|nil
---@field Items fun(): table
---@field Open fun(invType: string, data?: table|string|number): boolean
---@field OpenStash fun(id: string, data?: TSSStashData): boolean
---@field Close fun(): boolean

---@class TSSUsedItem
---@field name string Registered item name.
---@field metadata table Metadata (normalized from metadata or info).
---@field info table Alias of metadata.
---@field slot? integer Provider slot, when supplied.
---@field count? number Provider count, when supplied.
---@field amount? number Alias of count.

---@class TSSInventoryServerModule
---@field CreateUseableItem fun(item: string, callback: fun(source: integer, item: TSSUsedItem)): registered: boolean, error: string?
---@field CreateUsableItem fun(item: string, callback: fun(source: integer, item: TSSUsedItem)): registered: boolean, error: string?
---@field System fun(): system?: string, resource?: string
---@field Supports fun(feature: string): boolean
---@field Add fun(source: integer, item: string, amount?: integer, metadata?: table, slot?: integer, reason?: string): boolean
---@field Remove fun(source: integer, item: string, amount?: integer, metadata?: table|string, slot?: integer, reason?: string): boolean
---@field Count fun(source: integer, item: string, metadata?: table|string): integer
---@field Has fun(source: integer, item: string, amount?: integer, metadata?: table|string): boolean
---@field CanCarry fun(source: integer, item: string, amount?: integer, metadata?: table): boolean
---@field Player fun(source: integer): table|nil
---@field Items fun(): table
---@field RegisterStash fun(data: TSSStashData): boolean
---@field Open fun(source: integer, invType: string, data?: table|string|number): boolean
---@field OpenStash fun(source: integer, id: string, data?: TSSStashData): boolean
---@field Close fun(source: integer): boolean

---@class TSSProgressBarModule
---@field System fun(): system?: string, resource?: string
---@field Supports fun(feature: string): boolean
---@field Start fun(data: TSSProgressData): completed: boolean
---@field Stop fun()

---@class TSSTargetsModule
---@field System fun(): system?: string, resource?: string
---@field Supports fun(feature: string): boolean
---@field Entity fun(entity: TSSEntity|TSSEntity[], options: TSSTargetOption[]|TSSTargetOption, distance?: number): any
---@field Model fun(models: string|integer|(string|integer)[], options: TSSTargetOption[]|TSSTargetOption, distance?: number): any
---@field Box fun(data: TSSTargetZoneData, options: TSSTargetOption[], distance?: number): string|number|nil
---@field Circle fun(data: TSSTargetZoneData, options: TSSTargetOption[], distance?: number): string|number|nil
---@field CreateZoneAndProps fun(name: string, coords: vector3|vector4|table, radius: number?, length: number?, width: number?, heading: number?, minZ: number?, maxZ: number?, model1: string|integer?, model2: string|integer?, kind: 'circle'|'model'|'box'|string?, options: TSSTargetOption[]|TSSTargetOption, props?: table[], peds?: table[], debug?: boolean): zone: string|number|table|nil
---@field RemoveZoneAndProps fun(name: string)
---@field RemoveEntity fun(entity: TSSEntity|TSSEntity[]): any
---@field RemoveModel fun(models: string|integer|(string|integer)[]): any
---@field RemoveZone fun(zone: string|number): any
---@field Clear fun()

---@class TSSInteractionModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string, preferred?: string): boolean
---@field Create fun(data: TSSInteractionData): id?: integer
---@field Remove fun(id: string): boolean
---@field Clear fun()

---@class TSSVehicleKeysClientModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string): boolean
---@field Has fun(vehicleOrPlate: TSSEntity|string): boolean

---@class TSSVehicleKeysServerModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string): boolean
---@field Has fun(source: integer, vehicleOrPlate: TSSEntity|string): boolean
---@field Give fun(source: integer, vehicleOrPlate: TSSEntity|string): boolean
---@field Remove fun(source: integer, vehicleOrPlate: TSSEntity|string): boolean

---@class TSSFuelModule
---@field System fun(preferred?: string): system?: string, resource?: string
---@field Supports fun(feature: string): boolean
---@field Get fun(vehicle: TSSEntity): number
---@field Set fun(vehicle: TSSEntity, amount: number): boolean

---@class TSSBlipsModule
---@field Exists fun(blip?: integer): boolean Checks this consumer's blips.
---@field Update fun(blip: integer, data: TSSBlipData): boolean Changes supplied properties only.
---@field Coords fun(blip: integer): vector3|nil
---@field Colour fun(blip: integer): integer|nil
---@field Create fun(data: TSSBlipData): blip?: integer
---@field CreateEntity fun(data: TSSBlipData): blip?: integer Alias for `Create`.
---@field Remove fun(blip: integer)
---@field Clear fun()

---@class TSSPedsModule
---@field Create fun(data: TSSEntityCreateData|string|integer, coords?: vector3|vector4|table, options?: TSSEntityCreateOptions): ped?: TSSEntity
---@field CreateScenario fun(data: TSSEntityCreateData|string|integer, coords: vector3|vector4|table, scenario: string, options?: TSSEntityCreateOptions): ped?: TSSEntity
---@field CreateAnimated fun(data: TSSEntityCreateData|string|integer, coords: vector3|vector4|table, anim: table, options?: TSSEntityCreateOptions): ped?: TSSEntity
---@field Delete fun(ped: TSSEntity)
---@field Clear fun()

---@class TSSPropsModule
---@field Create fun(data: TSSEntityCreateData|string|integer, coords?: vector3|vector4|table, options?: TSSEntityCreateOptions): prop?: TSSEntity
---@field Delete fun(prop: TSSEntity)
---@field Clear fun()

---@class TSSVehiclesModule
---@field Create fun(data: TSSEntityCreateData|string|integer, coords?: vector3|vector4|table, options?: TSSEntityCreateOptions): vehicle?: TSSEntity
---@field Delete fun(vehicle: TSSEntity)
---@field Clear fun()

---@class TSSWorldModule
---@field ResourceName fun(): string
---@field Face fun(target: TSSEntity|vector3|table, ped?: TSSEntity, timeout?: integer): boolean
---@field CreateDistanceProp fun(data: table, options?: table): TSSDistanceController|nil
---@field CreateDistancePed fun(data: TSSEntityCreateData|string|integer, coords: vector3|vector4|table, options?: table): TSSDistanceController|nil

---@class TSSLocaleModule
---@field Language fun(): string
---@field Translate fun(key: string, ...): string
---@field Exists fun(key: string): boolean
---@field T fun(key: string, ...): string Alias for `Translate`.

---@class TSSCapabilitiesModule
---@field Resource fun(resource: string): boolean
---@field Module fun(name: string): boolean
---@field Modules fun(): string[]
---@field LoadedModules fun(): string[]
---@field Config fun(name: string): any
---@field Resources fun(): table<string, {resource: string, started: boolean, state: string}>
---@field Snapshot fun(): table

---@class TSSDiagnosticsModule
---@field Lines fun(): string[]
---@field Print fun(): string[]

---@class TSSGroupsModule
---@field System fun(): system?: TSSFrameworkName, resource?: string
---@field Supports fun(feature: string): boolean
---@field BossRoles fun(role: string): table<string, integer>
---@field ManagementSystem fun(): system?: string, resource?: string
---@field IsJobBoss fun(role?: string, source?: integer): boolean
---@field IsGangBoss fun(role?: string, source?: integer): boolean
---@field OpenBossMenu? fun(role?: string): boolean Client only.
---@field OpenGangMenu? fun(role?: string): boolean Client only.

---@class TSSUIClientModule
---@field Notify fun(data: TSSNotifyData): boolean
---@field Progress fun(data: TSSProgressData): boolean
---@field HideProgress fun(): boolean
---@field Menu fun(data: table, callback?: fun(...)): integer|false
---@field Context fun(data: table, callback?: fun(...)): integer|false
---@field Input fun(data: table, callback?: fun(...)): integer|false
---@field Close fun(): boolean

---@class TSSUIServerModule
---@field Notify fun(data: TSSNotifyData, source: integer): boolean
---@field Progress fun(data: TSSProgressData, source: integer): boolean
---@field HideProgress fun(source: integer): boolean

---@class TSSDebugModule
---@field Print fun(...: any) Prints when bridge debugging is enabled, prefixed with the caller name.
---@field FormatLocationTable fun(entries: table[], tableName?: string): string
---@field FormatLocationTables fun(tables: table<string, table[]>, order?: string[]): string
---@field FormatChairTable fun(entries: table[], label?: string, icon?: string): string
---@field SetEnabled fun(state: boolean)

---@class TSSCommandArgument
---@field name string Key supplied to the callback's parsed arguments.
---@field type? 'string'|'number'|'integer'|'boolean'|'rest' Defaults to string. Rest must be last.
---@field optional? boolean Defaults to false.
---@field help? string Argument description.
---@field options? (string|table)[] Autocomplete choices; these do not restrict accepted values.

---@class TSSCommandOptions
---@field description? string Help text.
---@field category? string Suggestion category, defaults to general.
---@field arguments? TSSCommandArgument[] Ordered arguments.
---@field permission? string|string[]|false Server ACE name(s), OR command.<name>. Defaults to public.
---@field allowConsole? boolean Server console access, defaults to true.
---@field hidden? boolean Hide suggestions without disabling execution.
---@field debugOnly? boolean Requires the bridge's debug setting for execution and suggestions.

---@class TSSCommandsModule
---@field Register fun(name: string, options: TSSCommandOptions, handler: fun(source: integer, args: table, rawCommand: string, rawArgs: string[])): boolean, string? Registers or updates a command owned by this resource.
---@field Unregister fun(name: string): boolean Disables a command owned by this resource and removes suggestions.
---@field Clear fun() Disables all commands owned by this resource.
---@field List fun(source?: integer): table[] Lists visible owned commands; server source defaults to console.
---@field Refresh fun() Refreshes command suggestions after permission/debug changes.

---@class TSSClientModules
---@field Commands? TSSCommandsModule
---@field Framework? TSSFrameworkModule
---@field Player? TSSPlayerClientModule
---@field Banking? TSSBankingClientModule
---@field Billing? TSSBillingModule
---@field Notify? TSSNotifyModule
---@field TextUI? TSSTextUIClientModule
---@field Callbacks? TSSCallbacksClientModule
---@field Inventory? TSSInventoryClientModule
---@field ProgressBar? TSSProgressBarModule
---@field Targets? TSSTargetsModule
---@field Interaction? TSSInteractionModule
---@field VehicleKeys? TSSVehicleKeysClientModule
---@field Fuel? TSSFuelModule
---@field UI? TSSUIClientModule
---@field Blips? TSSBlipsModule
---@field Peds? TSSPedsModule
---@field Props? TSSPropsModule
---@field Vehicles? TSSVehiclesModule
---@field World? TSSWorldModule
---@field Locale? TSSLocaleModule
---@field Capabilities? TSSCapabilitiesModule
---@field Diagnostics? TSSDiagnosticsModule
---@field Groups? TSSGroupsModule
---@field Debug? TSSDebugModule

---@class TSSServerModules
---@field Commands? TSSCommandsModule
---@field Framework? TSSFrameworkModule
---@field Player? TSSPlayerServerModule
---@field Banking? TSSBankingServerModule
---@field Notify? TSSNotifyModule
---@field TextUI? TSSTextUIServerModule
---@field Callbacks? TSSCallbacksServerModule
---@field Inventory? TSSInventoryServerModule
---@field VehicleKeys? TSSVehicleKeysServerModule
---@field UI? TSSUIServerModule
---@field Locale? TSSLocaleModule
---@field Capabilities? TSSCapabilitiesModule
---@field Diagnostics? TSSDiagnosticsModule
---@field Groups? TSSGroupsModule
---@field Debug? TSSDebugModule
