# Usable-item registration

Server API: `TSS.Inventory.CreateUseableItem(itemName, callback) -> boolean, error?`.

`CreateUsableItem` is an alias. Item names are lowercased. Registration calls
the selected framework directly: QB-Core's `Functions.CreateUseableItem`,
Qbox's `CreateUseableItem` export, or ESX's `RegisterUsableItem`.

The original callback is passed unchanged. Its arguments, return values,
replacement and lifetime follow the framework. The bridge does not normalize
item data, track ownership, create definitions or consume items. Register after
the framework starts and re-register after restarting it.

`TSS.Inventory.Supports('usable')` reports whether a supported framework is
started on the server. Registration methods are absent from the client API.
The inventory must use the selected framework's usable-item registry;
successful registration alone does not guarantee inventory dispatch.

For OX, the bridge now relies on its framework integration, without installing
`usingItem` hooks or changing item definitions. In the installed OX dispatch,
framework callbacks require `consume` omitted/false and a working
`server.UseItem` integration. `consume = 0` takes the native use path instead.

Registration returns false and an error for invalid arguments, unavailable
frameworks or failed registration. A nil framework return counts as success.
There are no inventory-specific registration exports or bridge stop cleanup.
