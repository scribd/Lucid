# Lucid - CoreData

A big advantage of Lucid is that it completely abstracts the use of `CoreData` by containing it in `CoreDataStore`. However, there are several `CoreData` specificities to keep in mind when using `CoreDataStore` with Lucid.

## `CoreDataManager`

`CoreDataManager` is an object in charge of initializing the `CoreData` stack and keeping a singular reference to it. In fact, it is also holding one single `NSManagedObjectContext`, which avoids having to merge multiple contexts.

Once injected into the `CoreDataStore`, `CoreDataManager` lazily loads the `CoreData` stack on its first access. This means you can start using Lucid right after the application has launched without having to wait for `CoreData` to initialize. Any requests that hit a CoreData store will just end up being slightly delayed.

## Migrations

One of the biggest hassles of `CoreData` is its migration system. Thankfully, Lucid provides the tools to write them, and ensures they succeed and are executed at the right time.

There are two types of migrations:

- **Lightweight**: Model changes for which the migration can be inferred. For example, a renaming a property, adding a property with a default value, etc. These simply rely on the built-in CoreData lightweight migration system.
- **Heavy**: Model or data changes for which the migration cannot be inferred. For example, adding a property without a default value, removing a case to an enum subtype, etc. Lucid adds custom support for heavy migration.

### Writing a Heavy Migration

Since lightweight migrations are automatically inferred, there's no code to write for them to work. However, heavy migrations need all your attention.

To register a series of migrations, Lucid needs to know where to read them from. This is configured in the `.lucid.yaml` configuration file:

```yaml
core_data_migrations_function: myCoreDataMigrations
```

The next thing to do is to write that function:

```swift  
func myCoreDataMigrations() -> [CoreDataManager.Migration] {
  return [
    Migration(version: .appVersion("1.1")) { context in
      ...
    }
  ]
}
```

#### Data Migration

A migration can be useful even though the `CoreData` model hasn't actually changed. 

Here's an example of how to capitalize stored titles during an update:

```swift
func myCoreDataMigrations() -> [CoreDataManager.Migration] {
  return [
    Migration(version: .appVersion("1.1")) { context in
      let fetchRequest: NSFetchRequest<ManagedMyEntity_1_0> = ManagedMyEntity_1_0.fetchRequest()
      do {
        for entity in try context.fetch(fetchRequest) {
        	entity.title = entity.title.capitalized
        }
      } catch {
        return .failure(.coreData(error as NSError))
      }
      return .success(())
    }
  ]
}
```

#### Data Model Migration

When the `CoreData` model is changing, you must specify a new model history version in the `Entity's` JSON description file.

For example, the following code tells Lucid to generate a new `CoreData` entity: `ManagedMyEntity_1_1`.

```json
"version_history": [
  {
    "version": "1.0"
  },
  {
    "version": "1.1"
  }
]
```

This gives us the opportunity to write a migration from `ManagedMyEntity_1_0` to `ManagedMyEntity_1_1`:

```swift
func myCoreDataMigrations() -> [CoreDataManager.Migration] {
  return [
    Migration(version: .appVersion("1.1")) { context in
      let fetchRequest: NSFetchRequest<ManagedMyEntity_1_0> = ManagedMyEntity_1_0.fetchRequest()
      do {
        for oldEntity in try context.fetch(fetchRequest) {
          let newEntity = ManagedMyEntity_1_1(context: context)
          
          // Filling unchanged properties with the old entity's values.
          let success = CoreDataManager.migrate(from: oldEntity, to: newEntity) { ($0, $1) }
          
          // Filling new properties
          newEntity.firstName = oldEntity.name.split(separator: " ").first
          newEntity.lastName = oldEntity.name.split(separator: " ").last
          
          if success == false {
            context.delete(newEntity)
          }
          
          // Keep in mind this migration will run only once.
          // It is important to remove old entities as it is your only chance to free that memory.
          context.delete(oldEntity)
        }
      } catch {
        return .failure(.coreData(error as NSError))
      }
      return .success(())
    }
  ]
}
```

### Migrations' Tests

It is very easy to mistake a lightweight migration for a heavy migration. Publishing **a failing migration leads to a permanent loss of your users' local database**, so it is crucial they work correctly.

To prevent this from happening as much as possible, Lucid provides a series of Unit Tests (`CoreDataMigrationTests`). These tests are re-generated for every new version of the entity descriptions. The tests try to migrate databases using every previous version of the `CoreData` model to the newest one.

**Important:** Alongside these tests, Lucid also generates the test case `ExportSQLiteFile` which automatically exports a snapshot of a dummy database into an `sqlite` for the current entity's description version. These snaphots are required for `CoreDataMigrationTests` to work properly, so it is important to run them often so that one snapshot is being stored for each version of the entity descriptions.
