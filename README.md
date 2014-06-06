# Fauna

Experimental Ruby client for [Fauna](http://fauna.org).

## Installation

The Fauna ruby client is distributed as a gem. Install it via:

    $ gem install fauna

Or if you use Bundler, add it to your application's `Gemfile`:

    gem 'fauna'

And then execute:

    $ bundle

## Compatibility

Tested and compatible with MRI 1.9.3. Other Rubies may also work.

## Basic Usage

First, require the gem:

```ruby
require "rubygems"
require "fauna"
```

### Configuring the API

All API requests start with an instance of `Fauna::Connection`.

Creating a connection requires either a token, a server key, or a
client key.

Let's use a server key we got from our [Fauna Cloud console](https://fauna.org/account/databases):

```ruby
server_key = 'ls8AkXLdakAAAALPAJFy3LvQAAGwDRAS_Prjy6O8VQBfQAlZzwAA'
```
Now we can make a global database-level connection:

```ruby
$fauna = Fauna::Connection.new(secret: server_key)
```

You can optionally configure a `logger` on the connection to ease
debugging:

```ruby
require "logger"
$fauna = Fauna::Connection.new(
  secret: server_key,
  logger: Logger.new(STDERR))
```

### Client Contexts

The easiest way to work with a connection is to open up a *client
context*, and then manipulate resources within that context:

```ruby
Fauna::Client.context($fauna) do
  user = Fauna::Resource.create('users', email: "taran@example.com")
  user.data["name"] = "Taran"
  user.data["profession"] = "Pigkeeper"
  user.save
  user.delete
end
```

By working within a context, not only are you able to use a more
convienient, object-oriented API, you also gain the advantage of
in-process caching.

Within a context block, requests for a resource that has already been
loaded via a previous request will be returned from the cache and no
query will be issued. This substantially lowers network overhead,
since Fauna makes an effort to return related resources as part of
every response.

### Fauna::Resource

All instances of fauna classes have built-in accessors for common
fields:

```ruby
Fauna::Client.context($fauna) do
  user = Fauna::Resource.create('users', constraints: {"username" => "taran77"})

  # fields
  user.ref       # => "users/123"
  user.ts        # => 2013-01-30 13:02:46 -0800
  user.deleted?  # => false
  user.constraints # => {"username" => "taran77"}

  # data and references
  user.data       # => {}
  user.references # => {}

  # resource events timeline
  user.events
end
```

Fauna resources must be created and accessed by ref, i.e.

```ruby
pig = Fauna::Resource.create 'classes/pigs'
pig.data['name'] = 'Henwen'
pig.save
pig.ref # => 'classes/pigs/42471470493859841'

# and later...

pig = Fauna::Resource.find 'classes/pigs/42471470493859841'
# do something with this pig...
````

## Transactions

Transactions can be executed by nesting API calls inside a transaction block. Transactions
bypass the client cache and post directly to the connection. Transaction variables are escaped
before the transaction is executed.

Actions can include `:data`, `:constraints`, `:references`, and `:permissions` hashes.

Variables are allowed per the API documentation. Both forms (`$variable` and `${variable}`)
may be used the constraints and references. In the `:data` hash, only the `${variable}` form
is allowed. All other dollar signs will be escaped. Parameter values may be supplied as
arguments to the `execute` method.

Action methods return their index in the transaction list, which can be used to build complex
sets of references out of numeric variables.

```
create_spell_transaction = Fauna::Transaction.new do |t|
  t.post("classes/spells",
    :data => {
      "blessing" : "$blessing",
      "strength" : "$strength",
      "text" : "Draw Drynwyn only of thou royal blood",
      "transferable" : true,
      "transfer_price": "$5 in ${transfer_currency}"
    },
    :permissions : {
      "read" : "users/self",
      "write" : "users/self"
    }
  )
  t.put("users/self/sets/spellbook/$0")
  t.get("$0")
end

spell = create_spell_transaction.execute("blessing" => true, "strength" => 100, "transfer_currency" => "Gold Coins")
```

Transaction blocks can also be executed directly, without instantiating a
transaction object.

```
Fauna::Transaction.execute do |t|
  t.post("classes/spells",
    :data => {
      "blessing" : true,
      "strength" : 100,
      "text" : "Draw Drynwyn only of thou royal blood"
      "transferable" : true,
      "transfer_price" : "$5 in Gold Coins"
    },
    :permissions : {
      "read" : "users/self",
      "write" : "users/self"
    }
  )
  t.put("users/self/sets/spellbook/$0")
  t.get("$0")
end

```

## Rails Usage

Fauna provides a Rails helper that sets up a default context in
controllers, based on credentials in `config/fauna.yml`:

```yaml
development:
  email: taran@example.com
  password: secret
  secret: secret_key
test:
  email: taran@example.com
  password: secret
```

(In `config/fauna.yml`, if an existing server key is specified, the
email and password can be omitted. If a server key is not
specified, a new one will be created each time the app is started.)

Then, in `config/initializers/fauna.rb`:

```ruby
require "fauna/rails"
```

## Running Tests

You can run tests against Fauna Cloud. Set the `FAUNA_ROOT_KEY` environment variable to your CGI-escaped email and password, joined by a `:`. Then run `rake`:

```bash
export FAUNA_ROOT_KEY="test%40fauna.org:secret"
rake
```

## Further Reading

Please see the Fauna REST Documentation for a complete API reference,
or look in [`/test`](https://github.com/fauna/fauna-ruby/tree/master/test)
for more examples.

## Contributing

GitHub pull requests are very welcome.

## LICENSE

Copyright 2013 [Fauna, Inc.](https://fauna.org/)

Licensed under the Mozilla Public License, Version 2.0 (the
"License"); you may not use this software except in compliance with
the License. You may obtain a copy of the License at

[http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing
permissions and limitations under the License.
