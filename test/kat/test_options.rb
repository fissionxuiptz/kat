require 'minitest/autorun'
require 'kat/options'

describe Kat::Options do
  describe 'options' do
    it '' do
      Kat::Options.options_map.must_be_instance_of Hash
    end
  end
end
