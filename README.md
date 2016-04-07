# Sequel::PgToJson

Uses native PG functions for fast but simple JSON serialization.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sequel-pg_to_json', git: 'git@git.noxqsapp.nl:gems/sequel-pg_to_json.git'
```

And then execute:

    $ bundle

## Usage

Use it for all Sequel Models:
```ruby
Sequel::Model.plugin :pg_to_json
```

Or use it for only a single model:
```ruby
class User < Sequel::Model
  plugin :pg_to_json
end
```

Using this plugin requires activating the pg_json extension for your database.
```ruby
DB.extension :pg_json
```
