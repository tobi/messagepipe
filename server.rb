require 'rubygems'
require 'eventmachine' 
require 'msgpack'

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
        result = receive_object(msg)        
        send_data([RET_OK, result].to_msgpack)
      rescue => e
        send_data([RET_E, "#{e.class.name}: #{e.message}"].to_msgpack)
      end
    end
  end

  def receive_object(msg)    
    cmd, method, args = *msg

    puts "* #{method} with #{args.length} arg(s)"


    if cmd != CMD_CALL
      close
      raise 'Bad client'
    end

    if method and public_methods.include?(method)
      __send__(method, *args)
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

