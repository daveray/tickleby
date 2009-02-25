# Copyright (c) 2009, Dave Ray <daveray@gmail.com>

class TclStringInput
 
  def initialize(input)
    @input = input.to_s.split(//u)
    @i = 0
  end

  # Look ahead n places in the input. If n points past the end of input then
  # an empty string is returned. Otherwise, returns a single character as a
  # string.
  def look_ahead(n = 0)
    if eof?(n) then "" else @input[@i + n] end
  end

  # Consume n characters starting with the current position.
  def consume(n = 1)
    @i = [@i + n, @input.length].min
  end

  # Returns the number of characters remaining in the input
  def remaining
    @input.length - @i
  end

  # Returns true if the input has reached its end
  def eof?(n = 0)
    return @i + n >= @input.length
  end
end

