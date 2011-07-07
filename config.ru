$LOAD_PATH.unshift 'lib'
require 'rack/async_stream'

app = proc do
  body = Object.new
  def body.each
    10.times do |i|
      yield "Number #{i}\n"
      sleep 0.3
    end
  end
  [200, {'Content-Type' => 'text/plain'}, body]
end

map '/fiber' do
  use Rack::AsyncStream, :logging => true, :stream => Rack::AsyncStream::FiberStream
  run app
end

map '/callcc' do
  use Rack::AsyncStream, :logging => true, :stream => Rack::AsyncStream::ContinuationStream
  run app
end

map '/thread' do
  use Rack::AsyncStream, :logging => true, :stream => Rack::AsyncStream::ThreadStream
  run app
end

map '/' do
  use Rack::AsyncStream, :logging => true
  run app
end
