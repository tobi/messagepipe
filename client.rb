require 'rubygems'
require 'eventmachine'
require 'msgpack'

class TcpTransport
  def initialize(host, port)    
    @socket = TCPSocket.open(host, port)
  end

  def read
    @socket.recv(4096)
  end

  def write(data)
    @socket.print(data)
  end

  def open?
    true
  end
end

class MessagePipe
  CMD_CALL = 0x01
  RET_OK   = 0x02
  RET_E    = 0x03

  class RemoteError < StandardError
  end

  def initialize(transport)
    @transport = transport
    @unpacker = MessagePack::Unpacker.new
  end

  def call(method, *args) 
    @transport.write([CMD_CALL, method, args].to_msgpack)

    while @transport.open? 
      @unpacker.feed(@transport.read)
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
    end

    raise RemoteError, 'disconnected'
  end
end


if __FILE__ == $0
  require "test/unit"

  class TestCase < Test::Unit::TestCase

    def setup
      $socket ||= MessagePipe.new(TcpTransport.new('localhost', 9191))
    end

    def test_simple_rpc
      assert_equal 'hello', $socket.call(:hi)
    end

    def test_large_rpc
      data = 'x' * 500_000
      assert_equal data, $socket.call(:echo, data)
    end

    def test_rpc_with_params
      assert_equal 3, $socket.call(:add, 1, 2)
      assert_equal 2000000, $socket.call(:add, 1000000, 1000000)
    end

    def test_throw_exception
      assert_raise(MessagePipe::RemoteError) do
        $socket.call :throw
      end    
    end

    def test_cannot_call_non_existing_method
      assert_raise(MessagePipe::RemoteError) do
        $socket.call :does_not_exist
      end    
    end

    def test_cannot_call_private_method
      assert_raise(MessagePipe::RemoteError) do
        $socket.call :private_method
      end    
    end 
  end

end