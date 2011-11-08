require 'rspec'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'gitmodel'

Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f}

MODELS = File.join(File.dirname(__FILE__), 'gitmodel', 'models')
$LOAD_PATH.unshift(MODELS)
Dir[File.join(MODELS, '*.rb')].each { |f| require f }

RSpec.configure do |c|
  c.mock_with :rspec
end

class TestEntity
  include GitModel::Persistable
end
class TestEntity2
  include GitModel::Persistable
end

_counter = 0
COUNTER = -> { (_counter += 1).to_s }
def make_id
  COUNTER.call
end

#GitModel.logger.level = ::Logger::DEBUG
GitModel.memcache_servers = ['localhost']
