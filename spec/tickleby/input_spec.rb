require File.expand_path(File.join(File.dirname(__FILE__), '/../helper'))

describe TclStringInput do

  it "should split its input and default to the first character" do
    input = TclStringInput.new("abcde")
    input.look_ahead.should == "a"
    input.look_ahead(1).should == "b"
    input.look_ahead(2).should == "c"
    input.look_ahead(3).should == "d"
    input.look_ahead(4).should == "e"
  end

  it "should return an empty string when looking past eof" do
    input = TclStringInput.new("abcde")
    input.look_ahead("abcde".length).should == ""
  end

  it "should consume characters and return current character on look_ahead" do
    input = TclStringInput.new("abcde")
    input.consume
    input.look_ahead.should == "b"
  end

  it "should consume multiple characters when asked" do
    input = TclStringInput.new("abcde")
    input.consume 2
    input.look_ahead.should == "c"
  end

  it "should return eof correctly" do
    input = TclStringInput.new("abcde")
    input.consume("abcde".length)
    input.eof?.should == true
  end

  it "should calculate the number of characters remaining in the input" do
    input = TclStringInput.new("abcde")
    input.remaining.should == 5
    input.consume
    input.remaining.should == 4
    input.consume
    input.remaining.should == 3
    input.consume
    input.remaining.should == 2
    input.consume
    input.remaining.should == 1
    input.consume
    input.remaining.should == 0
    input.consume
    input.remaining.should == 0
  end
end
