require 'spec_helper'

describe Rack::RestrictAccess::BlockFilter do
  it "should inherit from Filter class" do
    expect(Rack::RestrictAccess::BlockFilter.superclass).to eq(Rack::RestrictAccess::Filter)
  end

  describe "initialize" do
    it "should set defaults" do
      block_filter = Rack::RestrictAccess::BlockFilter.new
      expect(block_filter.instance_variable_get(:@body)).to eq(["<h1>Forbidden</h1>"])
      expect(block_filter.instance_variable_get(:@status_code)).to eq(403)
      expect(block_filter.instance_variable_get(:@ips)).to eq([])
      expect(block_filter.instance_variable_get(:@resources)).to eq([])
      expect(block_filter.instance_variable_get(:@applies_to_all_resources)).to be false
    end

    it "should execute block if given" do
      expect_any_instance_of(Rack::RestrictAccess::BlockFilter).to receive(:bogus_method)
      Rack::RestrictAccess::BlockFilter.new do
        bogus_method
      end
    end
  end

  describe "body" do
    it "should override default @body" do
      block_filter = Rack::RestrictAccess::BlockFilter.new
      expect(block_filter.instance_variable_get(:@body)).to eq(["<h1>Forbidden</h1>"])
      block_filter.body(["You shall not pass!"])
      expect(block_filter.instance_variable_get(:@body)).to eq(["You shall not pass!"])
    end

    it "should raise exception if given body does not respond to :each" do
      block_filter = Rack::RestrictAccess::BlockFilter.new
      expect{block_filter.body("You shall not pass!")}.to raise_exception(ArgumentError, "Body must respond to #each")
    end
  end

  describe "status_code" do
    it "should override default @status_code" do
      block_filter = Rack::RestrictAccess::BlockFilter.new
      expect(block_filter.instance_variable_get(:@status_code)).to eq(403)
      block_filter.status_code(401)
      expect(block_filter.instance_variable_get(:@status_code)).to eq(401)
    end
  end

  describe "blocks_resource?" do
    it "should delegate its arguments to #applies_to_resource?" do
      block_filter = Rack::RestrictAccess::BlockFilter.new
      expect(block_filter.instance_variable_get(:@applies_to_all_resources)).to be false
      expect(block_filter.instance_variable_get(:@resources)).to be_empty
      path = "/admin"
      expect(block_filter).to receive(:applies_to_resource?).with(path).and_return(false)
      expect(block_filter.blocks_resource?(path)).to eq false

      block_filter.instance_variable_set(:@resources, ["/admin"])
      expect(block_filter).to receive(:applies_to_resource?).with(path).and_return(true)
      expect(block_filter.blocks_resource?(path)).to eq true

      block_filter.instance_variable_set(:@resources, [])
      block_filter.instance_variable_set(:@applies_to_all_resources, true)
      expect(block_filter).to receive(:applies_to_resource?).with(path).and_return(true)
      expect(block_filter.blocks_resource?(path)).to eq true
    end
  end

  describe "blocks_ip?" do
    it "should delegate its arguments to #applies_to_ip?" do
      block_filter = Rack::RestrictAccess::BlockFilter.new
      expect(block_filter.instance_variable_get(:@ips)).to be_empty
      ip = "123.456.7.8"
      expect(block_filter).to receive(:applies_to_ip?).with(ip).and_return(false)
      expect(block_filter.blocks_ip?(ip)).to eq false

      block_filter.instance_variable_set(:@ips, ["123.456.7.8"])
      expect(block_filter).to receive(:applies_to_ip?).with(ip).and_return(true)
      expect(block_filter.blocks_ip?(ip)).to eq true
    end
  end
end
