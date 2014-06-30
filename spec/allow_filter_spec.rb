require 'spec_helper'

describe Rack::RestrictAccess::AllowFilter do
  it "should inherit from Filter class" do
    expect(Rack::RestrictAccess::AllowFilter.superclass).to eq(Rack::RestrictAccess::Filter)
  end

  describe "initialize" do
    it "sets defaults" do
      allow_filter = Rack::RestrictAccess::AllowFilter.new
      expect(allow_filter.instance_variable_get(:@ips)).to eq([])
      expect(allow_filter.instance_variable_get(:@resources)).to eq([])
      expect(allow_filter.instance_variable_get(:@applies_to_all_resources)).to be false
    end

    it "should execute block if given" do
      expect_any_instance_of(Rack::RestrictAccess::AllowFilter).to receive(:bogus_method)
      Rack::RestrictAccess::AllowFilter.new do
        bogus_method
      end
    end
  end

  describe "allows_resource?" do
    it "should delegate its arguments to #applies_to_resource?" do
      allow_filter = Rack::RestrictAccess::AllowFilter.new
      path = "/home"
      expect(allow_filter).to receive(:applies_to_resource?).with(path).and_return(false)
      expect(allow_filter.allows_resource?(path)).to eq false

      allow_filter.instance_variable_set(:@resources, ["/home"])
      expect(allow_filter).to receive(:applies_to_resource?).with(path).and_return(true)
      expect(allow_filter.allows_resource?(path)).to eq true

      allow_filter.instance_variable_set(:@resources, [])
      allow_filter.instance_variable_set(:@applies_to_all_resources, true)
      expect(allow_filter).to receive(:applies_to_resource?).with(path).and_return(true)
      expect(allow_filter.allows_resource?(path)).to eq true
    end
  end

  describe "allows_ip?" do
    it "should delegate its arguments to #applies_to_ip?" do
      allow_filter = Rack::RestrictAccess::AllowFilter.new
      ip = "123.456.7.8"
      expect(allow_filter).to receive(:applies_to_ip?).with(ip).and_return(false)
      expect(allow_filter.allows_ip?(ip)).to eq false

      allow_filter.instance_variable_set(:@ips, ["123.456.7.8"])
      expect(allow_filter).to receive(:applies_to_ip?).with(ip).and_return(true)
      expect(allow_filter.allows_ip?(ip)).to eq true
    end
  end
end
