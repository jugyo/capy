# Capy

The capy command to run the script written in Capybara DSL.

## Installation

    $ gem install capy

## Usage

### Capy Shell

    $ capy

### Running Script

Write script

    # example.capy

    visit 'http://www.wikipedia.org/'
    fill_in 'search', :with => 'ruby'
    click_on '  →  '
    stop

and

    $ capy example.capy

Change the browser:

    $ capy -b firefox example.capy

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## TODO

* write spec
