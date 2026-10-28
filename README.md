# DataMax

**DataMax** is a data management framework for Roblox designed to make storing, accessing, and managing player data simple and convenient. It provides an easy-to-use API for working with different data stores while helping developers organize their data efficiently.

One of DataMax's key features is its **cache system**, which provides fast access to data and allows critical changes to be handled in memory before being saved to persistent storage. This is especially useful for frequently updated or time-sensitive data, helping developers manage important changes without needing to perform a DataStore operation for every modification.

DataMax also provides **a separate cache for each store**, keeping data organized and independent. This structure makes it easier to manage different types of player data, such as inventories, currencies, statistics, and other game-related information, without mixing their cached data together.

With its straightforward API and organized data management approach, DataMax aims to reduce the complexity of working with Roblox DataStores and give developers a more convenient way to handle player data in their games.

## Key Features

- **Fast Data Access** — Access cached data without repeatedly requesting it from Roblox DataStores.
- **Per-Store Caching** — Each store maintains its own cache, keeping data organized and independent.
- **Convenient Data Management** — Use simple methods such as `Set`, `Add`, `Remove`, and `Update` to manage data.
- **Automatic Saving** — Automatically save data at configured intervals.
- **Session Management** — Manage player data sessions to help prevent conflicting access from different servers.
- **Simple Integration** — Designed to make data management easier to set up and use in Roblox projects.

DataMax is built to provide developers with a straightforward foundation for managing player data, whether they are building a small game or a larger Roblox experience.