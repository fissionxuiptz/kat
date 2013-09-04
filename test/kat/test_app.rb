require 'minitest/autorun'
require 'kat/app'

describe Kat::App do
  describe 'app' do
    it '' do
      app = Kat::App.new %w(predator -c movies)
      app.kat.must_be_instance_of Kat::Search
      app.kat.options.must_be_instance_of Hash
      #app.kat.options
    end
  end
end
