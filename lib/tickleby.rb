# Are we being run from the command-line?
tickleby_main = $0 =~ Regexp.compile("#{__FILE__}$")

# Add lib to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

# Require the library
require 'tickleby/commands'
require 'tickleby/interp'

# If we're running from the command-line ...
if tickleby_main
  interp = TclInterp.new
  ARGV.each do |arg|
    interp.eval(IO.read(arg))
  end
end

