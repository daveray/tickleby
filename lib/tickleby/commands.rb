# Copyright (c) 2009, Dave Ray <daveray@gmail.com>

module Tickleby
  class SetCommand
    def call(interp, words)
      frame = interp.get_frame.parent
      if words.length == 1
        return frame.get_variable(words[0])
      elsif words.length == 2
        frame.set_variable(words[0], words[1])
        return words[1]
      end
      
      # TODO raise error
    end
  end

  class GlobalCommand
    def call(interp, words)
      frame = interp.get_frame.parent
      words.each do |w|
        frame.map_variable w, interp.get_global_frame
      end
    end
  end

  class PutsCommand
    def call(interp, words)
      if words.length == 1
        puts words[0]
      end

      # TODO raise error
    end
  end


  class ProcCommand

    class Procedure
      def initialize(name, args, body)
        @name = name
        @args = args
        @body = body.split(//u)
      end

      def call(interp, words)
        frame = interp.stack[-1]
        @args.zip(words).each do |name,value|
          frame.set_variable name, value 
        end

        return interp.eval(StringInput.new(@body))
      end
    end

    def call(interp, words)
      name = words.shift
      args = words.shift.split
      body = words.shift
      p = Procedure.new(name, args, body)
      interp.add_command name, p
    end
  end

  class ReturnCommand
    def call(interp, words)
      interp.return_flag = :return
      if words.empty?
        ""
      else
        words.shift
      end
    end
  end
end
