require 'minitest/autorun'
require 'kat/field_map'

describe Kat do
  describe 'field map' do
    it 'is a hash' do
      Kat::FIELD_MAP.must_be_instance_of Hash
      Kat::FIELD_MAP.keys.wont_be_empty
      Kat::FIELD_MAP.values.wont_be_empty
      Kat::FIELD_MAP.keys.each do |k|
        k.must_be_instance_of Symbol
        Kat::FIELD_MAP[k].keys.each {|key| key.must_be_instance_of Symbol }
        Kat::FIELD_MAP[k][:desc].must_be_instance_of String if Kat::FIELD_MAP[k][:desc]
      end
    end
  end
end
