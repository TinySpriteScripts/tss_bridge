BridgeLabConfig = {
    Command = 'bridgelab',
    SpawnAtPlayer = true,
    DefaultLocation = { x = 215.76, y = -810.12, z = 30.73, w = 160.0 },

    PedModel = 's_m_m_autoshop_01',
    PedScenario = 'WORLD_HUMAN_CLIPBOARD',
    PropModel = 'prop_tool_box_04',
    DistancePropModel = 'prop_barrel_02a',
    VehicleModel = 'sultan',
    TestItem = 'water',

    ProgressDuration = 3500,
    TextUIDuration = 3500,
    StashSlots = 10,
    StashWeight = 25000,

    -- Mutation tests are disabled by default. When enabled, the server adds and
    -- removes the configured amounts to verify adapter round trips.
    EnableMutationTests = false,
    RequireMutationAce = true,
    MutationAce = 'tss_bridge.example.mutate',
    MoneyAccount = 'cash',
    MoneyAmount = 25,
    ItemAmount = 1,
}
