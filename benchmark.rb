require 'client'
require 'benchmark'

expectations = []

# Make rand predictable
srand(0)

# Build a series of 5000 tests, every test has format [expectation, method, *args]
expectations = (0..5000).collect do
	case rand(3)
	when 0
		num = rand(1000000)
		[num+num, :add, num, num]
	when 1
		['hello', :hi]
	when 2
		data = '.' * rand(10000)
		[data, :echo, data]
	end	
end

# Create 5 concurrent workers to pound the server with the fuzz test
pids = (0..4).collect do 
	fork do 
		socket = MessagePipe.new(TcpTransport.new('localhost', 9191))


		ms = Benchmark.realtime do 
			expectations.each do |expectation, method, *args|
				raise 'fail' unless socket.call(method, *args) == expectation				
			end
		end

		puts "benchmark finished in #{ms}s"
		exit 0

	end
end

# Wait for all forks to complete
Process.waitall