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

Determine how many workers you want to use first. Determine the number of physical CPUs this way:

    processes = SprocketsDerailleur::number_of_processors rescue 1

Then initialize the manifest with the workers you just determined:
  
    manifest = Sprockets::Manifest.new(Application::Sprockets, 'public/assets', processes)


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
