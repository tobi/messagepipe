require 'rubygems'
require 'eventmachine' 
require 'msgpack'
require 'benchmark'

# Server that receives MessagePack RPC
class MessagePipeServer < EventMachine::Connection
  CMD_CALL = 0x01
  RET_OK   = 0x02
  RET_E    = 0x03

  protected 

  def pac
    @pac ||= MessagePack::Unpacker.new  # Stream Deserializer
  end

  def receive_data(data)    
    pac.feed(data)        
    pac.each do |msg|      
      begin        

        response = nil

        secs = Benchmark.realtime do 
          response = begin 
            [RET_OK, receive_object(msg)]
          rescue => e
            [RET_E, "#{e.class.name}: #{e.message}"]
          end
        end

        send_data(response.to_msgpack)
        
        puts "#{object_id} - #{msg[1]}(#{msg[2].length} args) - [%.4f ms] [#{response[0] == RET_OK ? 'ok' : 'error'}]" % [secs||0]
        
      end
    end
  end

  def receive_object(msg)    
    cmd, method, args = *msg    

    if cmd != CMD_CALL
      unbind
      raise 'Bad client'
    end

    
    if method and public_methods.include?(method)
      return __send__(method, *args)
    else
      raise NoMethodError, "no method #{method} found."
    end
  end
end

class TestServer < MessagePipeServer

  def add(a, b)
    a + b
  end

  def hi
    'hello'
  end

  def echo(string)
    string
  end


  def throw
    raise StandardError, 'hell'
  end

  private

  def private_method
    'oh no'
  end

end

EventMachine::run do
  EventMachine::start_server "0.0.0.0", 9191, TestServer
end

