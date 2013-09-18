require 'minitest/autorun'
require File.dirname(__FILE__) + '/../../lib/kat/field_map'

describe Kat do
  describe 'field map' do
    let(:f) { Kat::FIELD_MAP }

    it 'is a hash' do
      f.must_be_instance_of Hash
    end

    it 'has symbolised keys' do
      f.keys.wont_be_empty
      f.keys.each { |key|
        key.must_be_instance_of Symbol
      }
    end

    it 'has a hash for values' do
      f.values.wont_be_empty
      f.values.each { |value|
        value.must_be_instance_of Hash
      }
    end

    it 'has symbolised keys in each value' do
      f.values.each { |value|
        value.keys.wont_be_empty
        value.keys.each { |key|
          key.must_be_instance_of Symbol
          case key
          when :desc
            value[key].must_be_instance_of String
          when :multi, :check, :input
            value[key].must_equal true
          when :short
            value[key].must_be_instance_of Symbol
            value[key].must_match /\A([a-z]|none)\Z/
          else
            value[key].must_be_instance_of Symbol
          end
        }
      }
    end
  end
end
