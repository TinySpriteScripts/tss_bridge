# Usable-item registration routes

Checked 2026-09-18. Public server API:
`TSS.Inventory.CreateUseableItem(itemName, callback) -> boolean, error?`.
`CreateUsableItem` is the same function.

These routes register handlers for existing items. Inventory installation,
framework integration and item definitions must already be configured. A
successful registration is not an in-game compatibility certification.

| Adapter | Registration route | Evidence / limits |
| --- | --- | --- |
| qb-inventory | Selected framework registry (normally QB-Core) | [QB registration documentation](https://qbcore.org/docs/qb-core/server-function-reference#qbcorefunctionscreateuseableitem); installed qb-core source. |
| ps-inventory | `CreateUsableItem` export | [Provider source](https://github.com/Project-Sloth/ps-inventory/blob/main/server/main.lua), which delegates to QB-Core. |
| lj-inventory | `CreateUsableItem` export | [Provider source](https://github.com/loljoshie/lj-inventory/blob/main/server/main.lua), which delegates to QB-Core. |
| core_inventory | Selected framework registry | [Vendor installation and framework compatibility](https://docs.c8re.store/core-inventory/installation), [vendor API catalog](https://docs.c8re.store/core-inventory/exports). Framework route is an integration inference; catalog has no independent usable-item registration export. |
| codem-inventory | Selected framework registry | [Vendor framework installation](https://codem.gitbook.io/codem-documentation/m-series/essentials/minventory-remake/installation) preserves framework item use. Also checked the installed CodeM MDT/phone framework integration code. |
| origen_inventory | `CreateUseableItem` export | [Published VMS integration source](https://docs.vames-store.com/assets/vms_cityhall/configuration-files/config.server.lua) calls this export. [Current Origen API catalog](https://docs.origennetwork.com/scripts/origen_inventory/exports) omits it: treat as version-dependent, not vendor-certified for every build. Missing export returns an error. |
| tgiann-inventory | Selected framework registry | [Vendor QB-Core source](https://github.com/tgiann/qb-core/blob/main/server/functions.lua), [vendor framework registration guidance](https://tgiann.gitbook.io/tgiann/items-not-usable-in-ox-inventory). Other framework combinations require testing with the installed TGIANN release. |
| tss-inventory | `CreateUseableItem` export | Verified directly in the local `sixties/.../[inventory]/tss-inventory/server/main.lua`: `registerUsableItemCallback` and its exported aliases. |
| inventory (Chezza) | ESX registry | Legacy ESX compatibility route. Current first-party Chezza registration documentation/source could not be retrieved; this adapter's item-use behavior remains unverified on a real Chezza server. No guessed inventory export is used. |
| ox_inventory | `usingItem` hook filtered to the registered item | [OX item guide](https://overextended.dev/docs/ox_inventory/Guides/creatingItems), [OX hook documentation](https://overextended.dev/docs/ox_inventory/Functions/Server/Hooks), and [OX server dispatch source](https://github.com/overextended/ox_inventory/blob/main/server.lua). Supports QB-Core, ESX and Qbox without depending on their usable-item registries. Consuming/native server handlers are rejected by this API. |

Framework routes use `QBCore.Functions.CreateUseableItem`,
[`exports.qbx_core:CreateUseableItem`](https://docs.qbox.re/resources/qbx_core/exports/server#createuseableitem),
or `ESX.RegisterUsableItem` on the **selected** framework. The bridge does not
register the same handler into several systems simultaneously.

The OX path requires an existing item with `consume = 0` (or a plain item with
`consume` omitted/false, which the bridge changes to `0` in OX's live server
definition). It dispatches from OX's documented `usingItem` hook and does not
consume the item. This avoids the framework callback limitation—stock OX only
documents that legacy route for ESX/Qbox—and also supports QB-Core. Native server
exports and positive/consuming values conflict and are rejected. Do not combine
the bridge callback with a native client use action for the same item.

The bridge tests load the real module loader and adapters with mocked providers,
checking export names, framework selection, normalization, errors, duplicate
ownership, replacement, stop cleanup, client isolation and blip-creator integration:

```powershell
lua tests/inventory_usable_spec.lua
```

They do not replace in-game tests on each paid inventory/version. Item providers
may require `useable = true` in their item definitions. An item with another
resource's native export/handler should keep that handler or be deliberately
reconfigured before assigning this bridge callback.
