# DataMax

**DataMax** is a data management framework for Roblox that makes working with player data easier. It provides a simple way to store, load, update, and manage data without having to deal with all the complexity of Roblox DataStores yourself.

DataMax uses a modular structure to keep things organized and easy to maintain. It also comes with a built-in caching system, allowing you to work with data in memory and save changes to DataStores when needed.

Each store has its own cache, so data stays separated and organized. This makes it easier to manage different types of player data, such as inventories, currencies, and statistics.

## Features

- **Modular Structure** — Different parts of DataMax are separated into modules, making the code easier to maintain and improve.
- **Caching System** — Work with cached data instead of making a DataStore request every time you need to access or modify something.
- **Per-Store Caching** — Each store has its own cache, keeping its data separate from other stores.
- **Easy Data Management** — Use simple methods like `Set`, `Add`, `Remove`, and `Update` to manage your data.
- **Automatic Saving** — Let DataMax save data automatically at configured intervals.
- **Session Management** — Helps prevent multiple servers from conflicting when accessing the same player's data.
- **Debugging** — Built-in debugging tools make it easier to follow what's happening and find potential problems.
- **Helper Functions** — Includes additional functions that handle common internal operations.
- **Type Definitions** — Organized type definitions make the code easier to understand and work with.

## Project Structure

DataMax is divided into separate modules, each with its own responsibility.

| Module | Description |
|---|---|
| Data | Handles loading, saving, and modifying data. |
| Cache | Manages cached data for each store. |
| Types | Contains shared type definitions. |
| Helper Functions | Handles additional operations used by the main modules. |

## Available Methods

Some of the main methods provided by DataMax:

- `GetData()`
- `Set()`
- `Add()`
- `Remove()`
- `Update()`
- `SaveData()`
- `WaitForLoad()`

## About DataMax

DataMax started as a small project to make working with Roblox DataStores less complicated. Over time, it has grown with new features, improvements, bug fixes, and changes to its internal structure.

The goal is to keep data management simple for developers while making the framework flexible enough to grow alongside their projects.

Whether you're working on a small game or a larger Roblox experience, DataMax aims to make handling player data a little easier.