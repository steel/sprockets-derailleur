# Sprockets::Derailleur

Speed up Manifest::Compile by forking processes 

## Installation

Add this line to your application's Gemfile:

    gem 'sprockets-derailleur'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sprockets-derailleur

Require `sprockets-derailleur` in environment file:
    
    require 'sprockets-derailleur'

## Usage

To install to an existing rails 3.2 project, first create a new file, 'sprockets_derailleur.rb' in config/initializers.

Here we need to override some core parts of the sprockets module.

```ruby
module Sprockets
  class StaticCompiler
  
    alias_method :compile_without_manifest, :compile
    def compile
    
      # Determine how many workers you want to use first. Determine the number of physical CPUs this way
      processes = SprocketsDerailleur::number_of_processors rescue 1
      
      puts "Multithreading on " + processes.to_s + " processors"
      puts "Starting Asset Compile: " + Time.now.getutc.to_s
      
      # Then initialize the manifest with the workers you just determined
      manifest = Sprockets::Manifest.new(env, target, processes)
      manifest.compile paths
      
      puts "Finished Asset Compile: " + Time.now.getutc.to_s
      
    end
  end
  
  class Railtie < ::Rails::Railtie
    config.after_initialize do |app|
      
      config = app.config
      next unless config.assets.enabled

      if config.assets.manifest
        path = File.join(config.assets.manifest, "manifest.json")
      else
        path = File.join(Rails.public_path, config.assets.prefix, "manifest.json")
      end

      if File.exist?(path)
        manifest = Sprockets::Manifest.new(app, path)
        config.assets.digests = manifest.assets
      end
      
    end
  end
  
end
```

The first block that overrides compile method starts sprockets derailleur with the chosen number of worker threads.
For maximum performance this should be the same number of processor cores on your compile machine.

The second block that is called after rails initializes is there because newer versions of sprockets are writing your
digested assets to manifest.json (Rails 4), instead of manifest.yml (Rails 3.2).

We therefore load in manifest.json using the Rails 4 method, as your asset compile will write this file. To avoid a duplicate
load, remember to delete the old manifest.yml from your public/assets folder.

A word of caution however, some gems that work with the asset pipeline still expect manifest.yml to exist.

Sprockets derailleur is known to work with (and possibly others):

- turbo-sprockets-rails3
- asset-sync

If you only intent to use digest assets, for example in production environments, you can also speed up your compile by using

```
rake assets:precompile:primary RAILS_ENV=production
```

This skips the non-digest compile, hence doubling speed (especially useful if syncing assets with a remote server).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
