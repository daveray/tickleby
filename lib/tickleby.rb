# Add lib to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

# Require the library
require 'tickleby/input'
require 'tickleby/commands'
require 'tickleby/interp'

# If we're running from the command-line ...
if $0 == __FILE__
  interp = Tickleby::Interp.new
  ARGV.each do |arg|
    interp.eval(Tickleby::StringInput.new(IO.read(arg)))
  end
end

