# Cerbos + ActiveRecord ORM Adapter

An adapater library that takes a [Cerbos](https://cerbos.dev) Query Plan ([PlanResources API](https://docs.cerbos.dev/cerbos/latest/api/index.html#resources-query-plan)) response and converts it into an [ActiveRecord](https://github.com/rails/rails/tree/main/activerecord) relation object. This is designed to work alongside a project using the [Cerbos Ruby SDK](https://github.com/cerbos/cerbos-sdk-ruby).

The following conditions are supported: `and`, `or`, `eq`, `ne`, `lt`, `gt`, `lte`, `gte` and `in`.

Not Supported:

- `every`
- `contains`
- `search`
- `mode`
- `startsWith`
- `endsWith`
- `isSet`
- Scalar filters
- Atomic number operations

## Requirements
- Cerbos > v0.16
- `@cerbos/http` or `@cerbos/grpc` client

## Usage

```
TODO: gem install support
```

Use the `Cerbos::QueryPlanAdapater` class:

```ruby
TODO:  example
```

Usage is similar to the Cerbos [Prisma](https://docs.cerbos.dev/cerbos/latest/recipes/orm/prisma/index.html) and [SQLAlchemy](https://docs.cerbos.dev/cerbos/latest/recipes/orm/sqlalchemy/index.html) adapters.
