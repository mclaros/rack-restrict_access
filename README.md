# Rack::RestrictAccess

Compares env 'REMOTE_ADDR' and 'PATH_INFO' against user-defined values to _block_ (403), _restrict_ (401 basic auth), or _allow_ access to the rack app.

Intended for use in simple access control. Should not be considered a security solution.

## Installation

Add this line to your application's Gemfile:

    gem 'rack-restrict_access'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-restrict_access

## Usage

Include in application.rb

```
# /config/application.rb

module ApplicationName
  class Application < Rails::Application

    ...

    config.middleware.use Rack::RestrictAccess do
      restrict do
        all_resources!
        # single/multiple delimited string(s), regexp(s), or array(s) of both
        credentials ENV['RESTRICTED_ACCESS_CREDENTIALS'], :delimiter => ","
      end

      # single/multiple delimited string(s), regexp(s), or array(s) of both
      allow do
        origin_ips ENV['ALLOWED_IPS'], "0.0.0.0", /192.168.\d{1}.\d.\d{1}$/, :delimiter => ","
      end
    end

    ...

  end
end
```

### DSL

There are three kinds of filters: `block`, `restrict`, and `allow`. They apply to `resources` (site paths) and `origin_ips` (REMOTE_ADDR/IP of requester), which the user designates.

#### `restrict`

Enforces HTTP Authentication for items passed through a block.

```
# require login the entire site

restrict do
  all_resources!
end
```

```
# restrict access to the specific path "/secret-place", and paths starting with "/admin"

restrict do
  resources /^\/admin\/.*/, "/secret-place"
  # also supports array(s) of strings/regexps
  # use :delimiter => STRING/REGEXP for delimited strings (also applies to strings in arrays)
end
```

```
#restrict access to any part of the site for the follolowing IPs

restrict do
  origin_ips "192.168.1.1,192.169.9.9", :delimiter => ","  # or Regexps
end
```

```
#or both!

restrict do
  # block access to the specific path "/secret-place", and paths starting with "/admin"
  resources /^\/admin\/*/, "/secret-place"

  # also block access to anything for these IPs:
  origins "192.168.1.1", "192.169.9.9"
end
```

##### Credentials

Designate one or multiple valid username/password combinations.


```
restrict do
  all_resources!

  #delimiter options required if dealing with delimited strings:

  credentials "stewie:coolwhip|brian:novel" :credentials_delimiter => ":", :credential_pair_delimiter => "|"

  #delimiter options default to :credentials => "," and :credential_pair_delimiter => ";" , respectively
end
```

#### `block`

Returns _403 FORBIDDEN_ for items passed through a block. Use same as `restrict`.

```
# block all the things!
block do
  all_resources!
end
```

```
block do
  # block access to the specific path "/secret-place", and paths starting with "/admin"

  resources /^\/admin\/*/, "/secret-place"

  # also supports array(s) of strings/regexps
  # use :delimiter => STRING/REGEXP for delimited strings (also applies to strings in arrays)

  # also block access to anything for these IPs:
  origin_ips "192.168.1.1", "192.169.9.9"
end

```

You may also designate a custom HTTP status code and response header, body for blocked resources

```
block do
  all_resources!

  status_code 401   #default is 403

  body ["You shall not pass!"]
  #body must respond to :each. Default is ["<h1>Forbidden</h1>"]
end
```

#### `allow`

Create exceptions for particular paths/IPs. These exceptions override `block` and `restrict` filters.

```
allow do
  #make this path open to anyone
  resources "/index"

  #allow this ip to bypass block/basic auth
  origin_ips "192.168.0.1"
end
```

## Contributing

1. Fork it ( http://github.com/<my-github-username>/rack-restrict_access/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
