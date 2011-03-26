require 'rubygems'
require 'eventmachine'
require 'msgpack'

class MessagePipeSocket
  CMD_CALL = 0x01
  RET_OK   = 0x02
  RET_E    = 0x03

  class RemoteError < StandardError
  end

  def initialize(host, port)
    @socket = TCPSocket.new(host, port)
    @unpacker = MessagePack::Unpacker.new
  end

  def call(method, *args) 
    @socket.print([CMD_CALL, method, args].to_msgpack)

    loop do 
      @unpacker.feed(@socket.recv(4096))
      @unpacker.each do |msg| 
        case msg.first
        when RET_E
          raise RemoteError, msg[1]
        when RET_OK
          return msg[1]
        else
          raise RemoteError, "recieved invalid message: #{msg.inspect}"
        end
      end
      raise RemoteError, 'disconnected' unless @socket.open? 
    end
  end
end




if __FILE__ == $0
  require "test/unit"

  class TestCase < Test::Unit::TestCase

    def setup
      $socket ||= MessagePipeSocket.new 'localhost', 9191
    end

    def test_simple_rpc
      assert_equal 'hello', $socket.call(:hi)
    end

    def test_rpc_with_params
      assert_equal 3, $socket.call(:add, 1, 2)
      assert_equal 2000000, $socket.call(:add, 1000000, 1000000)
    end

    def test_throw_exception
      assert_raise(MessagePipeSocket::RemoteError) do
        $socket.call :throw
      end    
    end

    def test_cannot_call_non_existing_method
      assert_raise(MessagePipeSocket::RemoteError) do
        $socket.call :does_not_exist
      end    
    end

    def test_cannot_call_private_method
      assert_raise(MessagePipeSocket::RemoteError) do
        $socket.call :private_method
      end    
    end 
  end

end