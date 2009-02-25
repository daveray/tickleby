require File.expand_path(File.join(File.dirname(__FILE__), '/../helper'))

describe TclInterp do
  
  before(:each) do
    @interp = TclInterp.new
  end

  def input(i) 
    TclStringInput.new(i)
  end

  it "should consume a comment" do
    input = input("# this is a comment \\\non multiple lines\n1234")
    @interp.consume_comment input
    input.remaining.should == 4
  end

  it "should consume whitespace" do
    input = input("   \t\f\n\r  hello")
    @interp.consume_whitespace input
    input.remaining.should == 5
  end

  it "should consume a comment with escaped backslashes" do
    input = input("# this is a comment \\\\\n1234")
    @interp.consume_comment input
    input.remaining.should == 4
  end

  it "should parse a normal variable" do
    input = input("$namespace::variable_123 tail")
    name = @interp.parse_variable input
    name.should == "namespace::variable_123"
    input.remaining.should == 5
  end

  it "should parse a normal variable with a backslash" do
    input = input("$var\\ tail")
    name = @interp.parse_variable input
    name.should == "var"
    input.remaining.should == 6
  end
 
  it "should parse a braced variable" do
    input = input("${{word_{count} tail")
    name = @interp.parse_variable input
    name.should == "{word_{count"
    input.remaining.should == " tail".length
  end

  it "should parse a variable with array index" do
    input = input("$var(123,45)tail")
    name = @interp.parse_variable input
    name.should == "var(123,45)"
    input.remaining.should == "tail".length
  end

  it "should parse an unquoted word" do
    input = input("unquoted-word\ntail")
    result = @interp.parse_unquoted_word input
    result.should == "unquoted-word"
    input.remaining.should == "\ntail".length
  end

  it "should parse an unquoted word with escapes" do
    input = input("un\\ quoted\\\"word tail")
    result = @interp.parse_unquoted_word input
    result.should == "un quoted\"word"
    input.remaining.should == " tail".length
  end

  it "should interpolate variables in unquoted words" do
    @interp.set_global('foo', 99)
    input = input("value-of-foo-is-$foo tail")
    result = @interp.parse_unquoted_word input
    result.should == "value-of-foo-is-99"
    input.remaining.should == " tail".length
  end

  it "should interpolate variables in quoted words" do
    @interp.set_global('foo', 99)
    input = input("\"the value of foo is $foo \"tail")
    result = @interp.parse_quoted_word input
    result.should == "the value of foo is 99 "
    input.remaining.should == "tail".length
  end

  it "should parse a quoted word" do
    input = input("\" this\nis a\tquoted\\\"word\" tail")
    result = @interp.parse_quoted_word input
    result.should == " this\nis a\tquoted\"word"
    input.remaining.should == " tail".length
  end

  it "should parse a braced word" do
    input = input("{this is $a \\} braced word} tail")
    result = @interp.parse_braced_word input
    result.should == "this is $a } braced word"
    input.remaining.should == " tail".length
  end

  it "should parse a braced word with nesting" do
    input = input("{this is {a b c d}\\} braced word} tail")
    result = @interp.parse_braced_word input
    result.should == "this is {a b c d}} braced word"
    input.remaining.should == " tail".length
  end

  it "should parse a command terminated with a semi-colon" do
    @interp.set_global("command", "test value")
    input = input("    # leading comment\n   $command    {a b c} \"hello there\"; tail")
    result = @interp.parse_command input
    result.should == ["test value", "a b c", "hello there"]
    input.remaining.should == " tail".length
  end

  it "should skip leading comments and whitespace before parsing a command" do
    
    input = input("    # comment\\\non multiple lines\n\n\n# another\n  set a b\ntail")
    result = @interp.parse_command input
    result.should == ["set", "a", "b"]
    input.remaining.should == "tail".length
  end

  it "should handle special escaped characters in quoted words" do
    input = input("\"\\a\\b\\f\\n\\r\\t\\v\\\\\"")
    result = @interp.parse_quoted_word input
    result.should == "\a\b\f\n\r\t\v\\"
    input.remaining.should == 0
  end

  it "should support the Tcl set command" do
    input = input("set name a; set $name 99\nset a")
    result = @interp.eval(input)
    result.should == "99"
  end
end
 
  

