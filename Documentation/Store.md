# Lucid - Store

In a way, `Store`s can be seen as drivers to read and write data to different physical places. Every `Store` imlements a unified protocol and are meant to be modular and composable.

A `Store` can be one of three types:

- `.memory`: Data are ephemeral. **Expected to be very fast and reliable**.
- `.disk`: Data are persisted to disk. **Expected to be relatively fast and very reliable**.
- `.remote`: Data are fully handled by a remote server. Relying on the network's connectivity, it **isn't expected to be fast nor reliable**.

**All types of stores are expected to be operating asynchronously and on a background thread.**

It is encouraged to implement your own stores in order to best fit your needs. However, Lucid comes with a few implementations which are meant to fit most scenarios.

- [`RemoteStore`](../Lucid/Stores/RemoteStore.swift): Transforms queries into valid `APIClientRequest`s to forward them to a `APIClientQueue` instance and transforms the response into entities.
- [`CoreDataStore`](../Lucid/Stores/CoreDataStore.swift): Transforms queries into `NSPredicate` to forward them to a CoreData stack and transforms the response into entities.
- [`InMemoryStore`](../Lucid/Stores/InMemoryStore.swift): Transforms queries into a series of entity identifiers to retrieve their corresponding entities from a dictionary. Compatible with queries only using identifiers. 
- [`LRUStore`](../Lucid/Stores/LRUStore.swift): Used as a **firewall in front of a disk and a memory `Store`** to make sure frequently used entities aren't repeatedly fetched from disk. Compatible with queries only using identifiers. 
