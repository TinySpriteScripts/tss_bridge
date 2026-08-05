# TSS Bridge Laboratory

This is a portable consumer resource for manually exercising the public
`tss_bridge` API from both realms. It intentionally lives inside the bridge
repository for development; move the entire `example_script` folder into your
server resources before starting it.

## Install

1. Move or copy this folder beside your other standalone resources.
2. Rename the folder if desired; callback ownership follows the actual resource name.
3. Ensure the bridge before the example resource:

```cfg
ensure tss_bridge
ensure example_script
```

4. Join as a fully loaded framework player and use `/bridgelab` or `F7`.

Additional commands:

- `/bridgelabaudit` runs the read-only API and callback audit directly.
- `/bridgelabspawn` creates the interactive test yard beside the player.
- `/bridgelabcleanup` removes everything created by this resource.
- `/bridgelabserver` asks the server to invoke the registered client callback.
- Running `bridgelabserver` from the server console prints bridge diagnostics.

## What it exercises

The client requests all 23 currently available client modules. The server
requests all 14 server modules. The menu provides focused tests for:

- framework detection, player data, jobs, gangs, groups and read-only balances;
- inventory detection, counts, item definitions, stash registration and opening;
- client-to-server and server-to-client callbacks;
- adapter notifications, built-in UI notifications, menus, contexts and inputs;
- client and server TextUI delivery;
- progress bars and cancellation;
- blips, peds, props, vehicles and distance-spawned props;
- entity, model, box and circle targets;
- target/TextUI interaction fallback;
- world facing and caller resource ownership;
- fuel reads/writes and vehicle-key round trips;
- locale, capabilities, diagnostics and debug table formatting;
- automatic cleanup when the consumer resource stops.

Audit details and server snapshots are printed to the F8 console. A missing
optional adapter may appear as `none`; the focused menu action shows whether its
fallback or operation succeeds.

The vehicle-key round trip first checks whether the player already has keys. If
so, it reports success without changing them; existing keys are never removed by
the test resource.

## Mutation safety

Money and item mutation tests are disabled by default. They use values from
`config.lua`, never values supplied by the client, and attempt an add/remove
round trip so the final balance and item count match their starting values.

To enable them:

```lua
BridgeLabConfig.EnableMutationTests = true
```

Grant the test permission to an appropriate admin group:

```cfg
add_ace group.admin tss_bridge.example.mutate allow
```

Do not enable mutation testing on a production server. Adapter failure between
the add and restore operations could leave the temporary money or item behind;
the returned report clearly flags whether restoration succeeded.

## Configuration

Edit `config.lua` to change models, test item, account, amounts, stash capacity,
command name, or whether the lab spawns beside the player. The supplied models
and location target GTA V/FiveM.
