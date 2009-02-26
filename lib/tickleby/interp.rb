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
    return_flag = nil
    result = ""
    while not input.eof?
      words = parse_command(input)
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
  def parse_command(input, embedded = false)
    words = []

    if embedded then input.consume end # skip bracket

    consume_comments_and_whitespace input

    while not input.eof? do
      c = input.look_ahead
      case c
        # a new line or semi-colon ends a command
        when /[;|\n]/ : input.consume; break
        when '"'      : words << parse_quoted_word(input)
        when '{'      : words << parse_braced_word(input)
        # skip all other whitespace
        when /\s/     : input.consume
      else
        # If this is an embedded command, check for closing bracket
        # otherwise the bracket is the start of an unquoted word.

        if embedded and c == "]"
          input.consume
          break
        end

        # everything else is handled as an unquoted word
        words << parse_unquoted_word(input, true)
      end
    end
    return words
  end

  # Parse an unquoted word. Performs variable and command interpolation
  # as necessary. Returns word and index just after word as a pair. If
  # end_at_close_bracket is true, the word will end at the first closing
  # bracket.
  def parse_unquoted_word(input, end_at_close_bracket = false)
    result = ""
    while not input.eof? do
      c = input.look_ahead
      case c
        when /[;|\s]/ : break
        when "\\"     : result += decode_escape(input)
        when "$"      : result += parse_and_resolve_variable(input)
        when "["      : result += eval_command(parse_command(input, true))
      else
        if end_at_close_bracket and c == "]"
          break
        end

        result += c
        input.consume
      end
    end
    return result
  end

  # Parse a quoted word. Assumes that s points at an opening quote.
  # Performs variable and command interpolation. Returns contents of
  # word without quotes and index just after closing quote as a pair.
  def parse_quoted_word(input)
    input.consume # skip starting quote
    result = ""
    while not input.eof? do
      c = input.look_ahead
      case c
        when "\"" : input.consume; return result
        when "\\" : result += decode_escape(input)
        when "$"  : result += parse_and_resolve_variable(input)
        when "["  : result += eval_command(parse_command(input, true))
      else
        result += c
        input.consume
      end
    end

    # TODO Better error
    raise "Unclosed quote"
  end

  # Parse a "braced" word. Assumes that s points at an opening brace.
  # Returns contents of braces and index just after closing brace as a pair.
  def parse_braced_word(input)
    input.consume
    result = ""
    while not input.eof? do
      c = input.look_ahead
      case c
        when "}" : input.consume; return result
        when "{" :
          result += rebrace(parse_braced_word(input))
          input.consume -1  # back up one
        when "\\" : 
          # only backslash newline, backslash, and braces
          la = input.look_ahead(1)
          if ["\n", "}", "{", "\\"].include? la
            result += la
            input.consume
          else
            result += c
          end
      else
        result += c
      end
      input.consume
    end
  
    # TODO: better error
    raise "Unclosed brace"
  end

  # Parse a variable and resolve it in the current stack frame. It is assume
  # that s points at a variable starter, i.e. $. Returns value of variable
  # and index right after variable as a pair. Raises an error if variable is
  # not found
  def parse_and_resolve_variable(input)
    name = parse_variable input
    value = @stack[-1].variables[name]
    if !value
      raise "No such variable '#{name}'"
    end
    return value
  end

  # Parse a variable from input starting at index s. Is is assumed that s
  # points at a variable starter, i.e. $. Returns name of variable and
  # index right after variable as a pair.
  def parse_variable(input)
    if '{' == input.look_ahead(1)
      parse_braced_variable(input)
    else
      parse_normal_variable(input)
    end
  end

  # Parse a "normal" variable. Returns variable name (no dollar sign) and
  # index right after end of variable name as a pair. It is assumed that
  # s points at a variable starter, i.e. $
  def parse_normal_variable(input)
    input.consume # skip $
    array_name = ""
    while not input.eof? do
      c = input.look_ahead
      case c
        when /\w|\d|[_:]/ :
          array_name << c
          input.consume
        when '('
          return array_name + parse_array_index(input)
      else
        return array_name
      end
    end
  end

  def parse_array_index(input)
    index = input.look_ahead
    input.consume # skip (
    while not input.eof? do
      c = input.look_ahead
      case c
        when /\w|\d|[_,]/ : 
          index << c
          input.consume
        when ')'          : 
          index << c
          input.consume
          return index
      else 
        input.consume
        return index
      end
    end
  end

  # Parse a variable with name in braces, e.g. ${var name}. Returns variable
  # name (no braces) and index right after closing brace as a pair. Is is
  # assumed that s points at a brace variable starter, i.e. ${
  def parse_braced_variable(input)
    input.consume(2) # skip ${
    name = ""
    while not input.eof? do
      c = input.look_ahead
      input.consume
      if c == '}'
        break
      end
      name << c
    end
    return name
  end

  def consume_comments_and_whitespace(input)
    consume_whitespace(input)
    while input.look_ahead == '#'
      consume_comment(input)
      consume_whitespace(input)
    end
  end

  # Consume a Tcl comment from the given input starting at index s. It
  # is assumed that s points at a comment starter (#). Returns index of
  # first non-comment character
  def consume_comment(input)
    while not input.eof? do
      case input.look_ahead
        when "\\" : 
          # In comments, only escaped backslashes and line endings matter
          if ["\n", "\\"].include? input.look_ahead(1)
            input.consume
          end
        when "\n" : input.consume; break 
      end
      input.consume
    end
  end

  # Consume whitespace from input starting at index s. Returns index of
  # first non-space character
  def consume_whitespace(input)
    while /\s/ =~ input.look_ahead do
      input.consume
    end
  end

  # Slap s and e at the start and end of value
  def restore_ends(value, s, e = s) return s + value + e end

  # Slap braces around the given string
  def rebrace(value) return restore_ends(value, "{", "}") end

  # Slap quotes around the given string
  def requote(value) return restore_ends(value, '"') end

  # Decode a Tcl escape sequence.
  #
  # input is an input array. s is the index to decode from. It is assumed
  # that s points at a backslash that starts the escape sequence. 
  # Returns the decode string and the index just after the escape sequence
  # as a pair.
  def decode_escape(input)
    c = input.look_ahead(1)
    case c
      when "a" : result = "\a"
      when "b" : result = "\b"
      when "f" : result = "\f"
      when "n" : result = "\n"
      when "r" : result = "\r"
      when "t" : result = "\t"
      when "v" : result = "\v"
      when "\\" : result = "\\"
      when /[01234567]/ : raise "Escaped octal Unicode not supported"
      when "x"  : raise "Escaped hex Unicode not supported"
      when "u"  : raise "Escaped Unicode not supported"
    else
      result = c
    end
    input.consume 2
    return result
  end

end

