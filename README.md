# Rack::AsyncStream

Ever tried to use streaming with Thin? Didn't work? Fear not! Just use this
middleware!

Works with Ruby 1.8.7, 1.9, JRuby, Rubinius, any Rails version since 2.3, any
version of Sinatra, your stand-alone Rack app and probably a lot more libraries,
frameworks and Ruby implementations.

## Usage

``` ruby
# config.ru
class SlowStream
  def each
    100.times do |i|
      yield "We're at #{i}\n"
      sleep 0.5
    end
  end
end

use Rack::AsyncStream
run proc { [200, {'Content-Type' => 'text/plain'}, SlowStream.new] }
```