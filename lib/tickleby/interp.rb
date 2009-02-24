# Copyright (c) 2009, Dave Ray <daveray@gmail.com>

# An entry in the interpreter's stack
class TclFrame
 
  attr_reader :interp
  attr_reader :parent
  attr_reader :variables

  # Initialize the frame with an interp and parent frame
  def initialize(interp, parent)
    @inter = interp
    @parent = parent
    @variables = {}
  end

  # set a variable in this frame
  def set_variable(name, value)
    value = value.to_str rescue value.to_s rescue value
    @variables[name] = value
  end
end

# Implementation of a Tcl interpreter based on the syntax rules described
# here: http://www.tcl.tk/man/tcl8.4/TclCmd/Tcl.htm 
class TclInterp
  
  attr_reader :variables
  attr_reader :stack
  attr_reader :commands
  attr_accessor :return_flag

  def initialize
    @commands = { 
      "set" => TclSetCommand.new,
      "puts" => TclPutsCommand.new,
      "proc" => TclProcCommand.new,
      "return" => TclReturnCommand.new
    }

    @stack = [TclFrame.new(self, nil)]
    @return_flag = nil
  end

  # Set a global interpreter variable
  def set_global(name, value)
    @stack[0].set_variable name, value
  end 

  # Get the value of a global variable
  def get_global(name)
    return @stack[0].variables[name]
  end

  # Install a new command. handler must have a call(interp, words)
  # method.
  def add_command(name, handler)
    @commands[name] = handler
  end

  # Evaluate the given input string in this interpreter
  def eval(input)
    if input.is_a? String 
      input = input.split(//u)
    end
    return_flag = nil
    i = 0
    result = ""
    while i < input.length
      words, i = parse_command(input, i)
      result = eval_command(words)
      if @return_flag
        return result
      end
    end
    return result
  end
  
  # Evaluate a list of words as a command in a new stack frame.
  # Returns the result of the command.
  def eval_command(words)
    name = words.shift
    command = @commands[name]
    if !command
      raise "Unknown command #{name}"
    end
    
    with_new_frame do
      return command.call(self, words)
    end
  end

  def with_new_frame
    @stack.push TclFrame.new(self, @stack[-1])
    begin
      yield
    ensure
      @stack.pop
    end
  end

  # Parse a single command, performing variable and command interpolation.
  # Returns a list of words and the index just after the end of the command
  # as a pair. Consumes leading whitespace and comment. If embedded is true,
  # this is treated as an embedded command that starts and ends with square
  # brackets.
  def parse_command(input, s, embedded = false)
    words = []

    if embedded then s += 1 end # skip bracket

    i = consume_whitespace(input, s)
    while look_ahead(input, i) == '#'
      i = consume_comment(input, i)
      i = consume_whitespace(input, i)
    end

    while i < input.length do
      c = input[i]
      case c
        # a new line or semi-colon ends a command
        when ";"  : return words, i + 1
        when "\n" : return words, i + 1
        when "\"" : 
          word, i = parse_quoted_word(input, i)
          words << word
        when "{" :
          word, i = parse_braced_word(input, i)
          words << word
        # skip all other whitespace
        when /\s/ :
          i += 1
      else
        # If this is an embedded command, check for closing bracket
        # otherwise the bracket is the start of an unquoted word.

        if embedded and c == "]"
          return words, i + 1
        end

        # everything else is handled as an unquoted word
        word, i = parse_unquoted_word(input, i, true)
        words << word
      end
    end
    return words, i
  end

  # Parse an unquoted word. Performs variable and command interpolation
  # as necessary. Returns word and index just after word as a pair. If
  # end_at_close_bracket is true, the word will end at the first closing
  # bracket.
  def parse_unquoted_word(input, s, end_at_close_bracket = false)
    i = s
    result = ""
    while i < input.length do
      c = input[i]
      case c
        when /\s/ : return result, i
        when ";" : return result, i
        when "\\" : 
          decoded, i = decode_escape(input, i)
          result += decoded
        when "$"  : 
          resolved, i = parse_and_resolve_variable(input, i)
          result += resolved
        when "["  :
          words, i = parse_command input, i, true
          result += eval_command words
      else
        if end_at_close_bracket and c == "]"
          return result, i
        end

        result += c
        i += 1
      end
    end
    return result, i
  end

  # Parse a quoted word. Assumes that s points at an opening quote.
  # Performs variable and command interpolation. Returns contents of
  # word without quotes and index just after closing quote as a pair.
  def parse_quoted_word(input, s)
    i = s += 1 # skip starting quote
    result = ""
    while i < input.length do
      c = input[i]
      case c
        when "\"" : return result, i + 1
        when "\\" : 
          decoded, i = decode_escape(input, i)
          result += decoded
        when "$"  : 
          resolved, i = parse_and_resolve_variable(input, i)
          result += resolved
        when "["  :
          words, i = parse_command input, i, true
          result += eval_command words
      else
        result += c
        i += 1
      end
    end

    # TODO Better error
    raise "Unclosed quote"
  end

  # Parse a "braced" word. Assumes that s points at an opening brace.
  # Returns contents of braces and index just after closing brace as a pair.
  def parse_braced_word(input, s)
    i = s + 1 # skip starting brace
    result = ""
    while i < input.length do
      c = input[i]
      case c
        when "}" : return result, i + 1
        when "{" :
          sub, i = parse_braced_word(input, i)
          result += rebrace(sub)
          i -= 1
        when "\\" : 
          # only backslash newline, backslash, and braces
          la = look_ahead(input, i + 1)
          if ["\n", "}", "{", "\\"].include? la
            result += la
            i += 1
          else
            result += c
          end
      else
        result += c
      end
      i += 1
    end
  
    # TODO: better error
    raise "Unclosed brace"
  end

  # Parse a variable and resolve it in the current stack frame. It is assume
  # that s points at a variable starter, i.e. $. Returns value of variable
  # and index right after variable as a pair. Raises an error if variable is
  # not found
  def parse_and_resolve_variable(input, s)
    name, e = parse_variable input, s
    value = @stack[-1].variables[name]
    if !value
      raise "No such variable '#{name}'"
    end
    return value, e
  end

  # Parse a variable from input starting at index s. Is is assumed that s
  # points at a variable starter, i.e. $. Returns name of variable and
  # index right after variable as a pair.
  def parse_variable(input, s)
    if '{' == look_ahead(input, s+1)
      parse_braced_variable(input, s)
    else
      parse_normal_variable(input, s)
    end
  end

  # Parse a "normal" variable. Returns variable name (no dollar sign) and
  # index right after end of variable name as a pair. It is assumed that
  # s points at a variable starter, i.e. $
  def parse_normal_variable(input, s)
    i = s += 1 # skip $
    while i < input.length do
      case input[i]
        when /\w|\d|[_:]/ : i += 1
        when '('
          array_index, e = parse_array_index input, i
          return input[s ... i].join + array_index , e
      else
        return input[s ... i].join, i
      end
    end
  end

  def parse_array_index(input, s)
    i = s + 1 # skip (
    while i < input.length do
      case input[i]
        when /\w|\d|[_,]/ : i += 1
        when ')'          : return input[s .. i].join, i + 1
      else 
          return input[s ... i].join, i + 1
      end
    end
  end

  # Parse a variable with name in braces, e.g. ${var name}. Returns variable
  # name (no braces) and index right after closing brace as a pair. Is is
  # assumed that s points at a brace variable starter, i.e. ${
  def parse_braced_variable(input, s)
    i = s += 2  # skip ${
    while i < input.length do
      if input[i] == '}'
        return input[s ... i].join, i + 1
      end
      i += 1
    end
    return input[s ... i].join, i
  end

  # Consume a Tcl comment from the given input starting at index s. It
  # is assumed that s points at a comment starter (#). Returns index of
  # first non-comment character
  def consume_comment(input, s)
    while s < input.length do
      case input[s]
        when "\\" : 
          # In comments, only escaped backslashes and line endings matter
          if ["\n", "\\"].include? look_ahead(input, s + 1)
            s += 1
          end
        when "\n" : return s + 1
      end
      s += 1
    end
    return s
  end

  # Consume whitespace from input starting at index s. Returns index of
  # first non-space character
  def consume_whitespace(input, s)
    while s < input.length do
      if !(/\s/ =~ input[s]) then return s end
      s += 1
    end
    return s
  end

  # Look ahead to index i of the given input array. Returns an empty
  # string if i is out of bounds.
  def look_ahead(input, i)
    if i < input.length then input[i] else "" end
  end

  # Slap s and e at the start and end of value
  def restore_ends(value, s, e) return s + value + e end

  # Slap braces around the given string
  def rebrace(value) return restore_ends(value, "{", "}") end

  # Slap quotes around the given string
  def requote(value) return restore_ends(value, '"', '"') end

  # Decode a Tcl escape sequence.
  #
  # input is an input array. s is the index to decode from. It is assumed
  # that s points at a backslash that starts the escape sequence. 
  # Returns the decode string and the index just after the escape sequence
  # as a pair.
  def decode_escape(input, s)
    c = look_ahead(input, s + 1)
    case c
      when "a" : return "\a", s + 2
      when "b" : return "\b", s + 2
      when "f" : return "\f", s + 2
      when "n" : return "\n", s + 2
      when "r" : return "\r", s + 2
      when "t" : return "\t", s + 2
      when "v" : return "\v", s + 2
      when "\\" : return "\\", s + 2
      when /[01234567]/ : raise "Escaped octal Unicode not supported"
      when "x"  : raise "Escaped hex Unicode not supported"
      when "u"  : raise "Escaped Unicode not supported"
    end
    return c, s + 2 
  end

end
