require File.expand_path(File.join(File.dirname(__FILE__), '/../helper'))

describe TclInterp do
  
  before(:each) do
    @interp = TclInterp.new
  end

  def input(i) 
    i.split(//u)
  end

  it "should consume a comment" do
    input = input("# this is a comment \\\non multiple lines\n1234")
    e = @interp.consume_comment input, 0
    e.should == input.length - 4
    input[e..input.length].join.should == "1234"
  end

  it "should consume whitespace" do
    input = input("   \t\f\n\r  hello")
    e = @interp.consume_whitespace input, 0
    e.should == input.length - 5
  end

  it "should consume a comment with escaped backslashes" do
    input = input("# this is a comment \\\\\n1234")
    e = @interp.consume_comment input, 0
    e.should == input.length - 4
    input[e..input.length].join.should == "1234"
  end

  it "should parse a normal variable" do
    input = input("$namespace::variable_123 tail")
    name, e = @interp.parse_variable input, 0
    name.should == "namespace::variable_123"
    e.should == input.length - 5
    input[e..input.length].join.should == " tail"
  end

  it "should parse a normal variable with a backslash" do
    input = input("$var\\ tail")
    name, e = @interp.parse_variable input, 0
    name.should == "var"
    e.should == input.length - 6
    input[e..input.length].join.should == "\\ tail"
  end
 
  it "should parse a braced variable" do
    input = input("${{word_{count} tail")
    name, e = @interp.parse_variable input, 0
    name.should == "{word_{count"
    input[e..input.length].join.should == " tail"
  end

  it "should parse a variable with array index" do
    input = input("$var(123,45)tail")
    name, e = @interp.parse_variable input, 0
    name.should == "var(123,45)"
    e.should == input.length - 4
    input[e..input.length].join.should == "tail"
  end

  it "should parse an unquoted word" do
    input = input("unquoted-word\ntail")
    result, e = @interp.parse_unquoted_word input, 0
    result.should == "unquoted-word"
    input[e..input.length].join.should == "\ntail"
  end

  it "should parse an unquoted word with escapes" do
    input = input("un\\ quoted\\\"word tail")
    result, e = @interp.parse_unquoted_word input, 0
    result.should == "un quoted\"word"
    input[e .. input.length].join.should == " tail"
  end

  it "should interpolate variables in unquoted words" do
    @interp.set_global('foo', 99)
    input = input("value-of-foo-is-$foo tail")
    result, e = @interp.parse_unquoted_word input, 0
    result.should == "value-of-foo-is-99"
    input[e .. input.length].join.should == " tail"
  end

  it "should interpolate variables in quoted words" do
    @interp.set_global('foo', 99)
    input = input("\"the value of foo is $foo \"tail")
    result, e = @interp.parse_quoted_word input, 0
    result.should == "the value of foo is 99 "
    input[e .. input.length].join.should == "tail"
  end

  it "should parse a quoted word" do
    input = input("\" this\nis a\tquoted\\\"word\" tail")
    result, e = @interp.parse_quoted_word input, 0
    result.should == " this\nis a\tquoted\"word"
    input[e .. input.length].join.should == " tail"
  end

  it "should parse a braced word" do
    input = input("{this is $a \\} braced word} tail")
    result, e = @interp.parse_braced_word input, 0
    result.should == "this is $a } braced word"
    input[e .. input.length].join.should == " tail"
  end

  it "should parse a braced word with nesting" do
    input = input("{this is {a b c d}\\} braced word} tail")
    result, e = @interp.parse_braced_word input, 0
    result.should == "this is {a b c d}} braced word"
    input[e .. input.length].join.should == " tail"
  end

  it "should parse a command terminated with a semi-colon" do
    @interp.set_global("command", "test value")
    input = input("    # leading comment\n   $command    {a b c} \"hello there\"; tail")
    result, e = @interp.parse_command input, 0
    result.should == ["test value", "a b c", "hello there"]
    input[e .. input.length].join.should == " tail"
  end

  it "should skip leading comments and whitespace before parsing a command" do
    
    input = input("    # comment\\\non multiple lines\n\n\n# another\n  set a b\ntail")
    result, e = @interp.parse_command input, 0
    result.should == ["set", "a", "b"]
    input[e .. input.length].join.should == "tail"
  end

  it "should handle special escaped characters in quoted words" do
    input = input("\"\\a\\b\\f\\n\\r\\t\\v\\\\\"")
    result, e = @interp.parse_quoted_word input, 0
    result.should == "\a\b\f\n\r\t\v\\"
    e.should == input.length
  end

  it "should support the Tcl set command" do
    input = "set name a; set $name 99\nset a"
    result = @interp.eval(input)
    result.should == "99"
  end
end
 
  

