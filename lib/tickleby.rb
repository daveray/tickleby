# Add lib to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

# Require the library
require 'tickleby/input'
require 'tickleby/commands'
require 'tickleby/interp'

# If we're running from the command-line ...
if $0 == __FILE__
  interp = TclInterp.new
  ARGV.each do |arg|
    interp.eval(TclStringInput.new(IO.read(arg)))
  end
end

