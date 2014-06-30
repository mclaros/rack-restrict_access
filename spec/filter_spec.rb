require 'spec_helper'

describe Rack::RestrictAccess::Filter do
  describe "initialize" do
    it "should set defaults" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@ips)).to eq([])
      expect(filter.instance_variable_get(:@resources)).to eq([])
      expect(filter.instance_variable_get(:@applies_to_all_resources)).to be false
    end

    it "should execute block if given" do
      expect_any_instance_of(Rack::RestrictAccess::Filter).to receive(:bogus_method)
      Rack::RestrictAccess::Filter.new do
        bogus_method
      end
    end
  end

  describe "restricts_resource?" do
    it "should delegate its arguments to #applies_to_resource?" do
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new
      expect(restrict_filter.instance_variable_get(:@applies_to_all_resources)).to be false
      expect(restrict_filter.instance_variable_get(:@resources)).to eq([])
      path = "/admin"
      expect(restrict_filter).to receive(:applies_to_resource?).with(path).and_return(false)
      expect(restrict_filter.restricts_resource?(path)).to eq false

      restrict_filter.instance_variable_set(:@resources, ["/admin"])
      expect(restrict_filter).to receive(:applies_to_resource?).with(path).and_return(true)
      expect(restrict_filter.restricts_resource?(path)).to eq true

      restrict_filter.instance_variable_set(:@resources, [])
      restrict_filter.instance_variable_set(:@applies_to_all_resources, true)
      expect(restrict_filter).to receive(:applies_to_resource?).with(path).and_return(true)
      expect(restrict_filter.restricts_resource?(path)).to eq true
    end
  end

  describe "restricts_ip?" do
    it "should delegate its arguments to #applies_to_ip?" do
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new
      expect(restrict_filter.instance_variable_get(:@ips)).to eq([])
      ip = "123.456.7.8"
      expect(restrict_filter).to receive(:applies_to_ip?).with(ip).and_return(false)
      expect(restrict_filter.restricts_ip?(ip)).to eq false

      restrict_filter.instance_variable_set(:@ips, ["123.456.7.8"])
      expect(restrict_filter).to receive(:applies_to_ip?).with(ip).and_return(true)
      expect(restrict_filter.restricts_ip?(ip)).to eq true
    end
  end

  describe "path_to_regexp" do
    let(:filter) { Rack::RestrictAccess::Filter.new }

    it "should return the given input if it's already a regexp" do
      reg = /\/secret\/?/
      expect(filter.path_to_regexp(reg)).to eq(reg)
    end

    it "should convert string into regexp with anchors" do
      str = '/secret'
      expect(filter.path_to_regexp(str)).to eq(/^\/secret\/?$/)
    end

    it "should raise exception if argument is does not respond to :match or :to_str" do
      expect{filter.path_to_regexp(999)}.to raise_exception(TypeError)
    end
  end

  describe "all_resources!" do
    it "should set @applies_to_all_resources to true" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@applies_to_all_resources)).to be false
      filter.all_resources!
      expect(filter.instance_variable_get(:@applies_to_all_resources)).to be true
    end
  end

  describe "resources" do
    it "should call path_to_regexp on given string and save the result to @resources" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@resources)).to be_empty
      arg = '/some-path'
      filter.resources(arg)
      expect(filter.instance_variable_get(:@resources)).to eq([/^\/some\-path\/?$/])
    end

    it "should handle multiple strings" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@resources)).to be_empty
      arg1 = '/some-path'
      arg2 = '/accounts'
      arg3 = '/admin'
      filter.resources(arg1, arg2, arg3)
      expect(filter.instance_variable_get(:@resources)).to eq([/^\/some\-path\/?$/, /^\/accounts\/?$/, /^\/admin\/?$/])
    end

    it "should handle delimited string when given delimiter string option" do
      csv = '/some-path,/accounts,/admin'
      filter2 = Rack::RestrictAccess::Filter.new
      expect(filter2.instance_variable_get(:@resources)).to be_empty
      filter2.resources(csv, delimiter: ',')
      expect(filter2.instance_variable_get(:@resources)).to eq([/^\/some\-path\/?$/, /^\/accounts\/?$/, /^\/admin\/?$/])
    end

    it "should handle delimited string when given delimiter regexp option" do
      regexp_delimited = '/some-path | /accounts | /admin'
      filter3 = Rack::RestrictAccess::Filter.new
      expect(filter3.instance_variable_get(:@resources)).to be_empty
      filter3.resources(regexp_delimited, delimiter: /[\s]*\|[\s]*/)
      expect(filter3.instance_variable_get(:@resources)).to eq([/^\/some\-path\/?$/, /^\/accounts\/?$/, /^\/admin\/?$/])
    end

    it "should not split string if no delimiter option is given" do
      not_delimited_csv = '/some-path,/accounts,/admin'
      filter1 = Rack::RestrictAccess::Filter.new
      expect(filter1.instance_variable_get(:@resources)).to be_empty
      filter1.resources(not_delimited_csv)
      expect(filter1.instance_variable_get(:@resources)).to eq([/^#{Regexp.escape(not_delimited_csv)}\/?$/])
    end

    it "should handle multiple delimited strings" do
      csv = "/one, /two, /three"
      tsv = "/four\t/five\t/six"
      filter = Rack::RestrictAccess::Filter.new
      filter.resources(csv, tsv, delimiter: /\s*,\s*|\t/)
      expect(filter.instance_variable_get(:@resources)).to eq([/^\/one\/?$/, /^\/two\/?$/, /^\/three\/?$/, /^\/four\/?$/, /^\/five\/?$/, /^\/six\/?$/])
    end

    it "should handle a regexp argument" do
      arg = /\/some\-path/
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@resources)).to be_empty
      filter.resources(arg)
      expect(filter.instance_variable_get(:@resources)).to eq([/\/some\-path/])
    end

    it "should handle multiple regexps" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@resources)).to be_empty
      arg1 = /\/some\-path/
      arg2 = /\/some\-other\-path/
      arg3 = /^\/exact$/
      filter.resources(arg1, arg2, arg3)
      expect(filter.instance_variable_get(:@resources)).to eq([/\/some\-path/, /\/some\-other\-path/, /^\/exact$/])
    end

    it "should handle single array of strings or regexps" do
      arr = ['/admin', /^.*\/secret\/?.*$/, '/users']
      filter = Rack::RestrictAccess::Filter.new
      filter.resources(arr)
      expect(filter.instance_variable_get(:@resources)).to eq([/^\/admin\/?$/, /^.*\/secret\/?.*$/, /^\/users\/?$/])
    end

    it "should handle multiple arrays of strings or regexps" do
      arr1 = ['/admin', /^.*\/secret\/?.*$/, '/users']
      arr2 = [/^\/first\/?$/, '/second', /^\/third/]
      filter = Rack::RestrictAccess::Filter.new
      filter.resources(arr1, arr2)
      expect(filter.instance_variable_get(:@resources)).to eq([/^\/admin\/?$/, /^.*\/secret\/?.*$/, /^\/users\/?$/, /^\/first\/?$/, /^\/second\/?$/, /^\/third/])
    end

    it "should split strings in array if delimiter is given" do
      arr1 = ['/first', '/second,/third', '/fourth']
      arr2 = [/^\/fifth\/?/, '/sixth,/seventh,/eighth', /^\/ninth/]
      filter = Rack::RestrictAccess::Filter.new
      filter.resources(arr1, arr2, delimiter: ',')
      expect(filter.instance_variable_get(:@resources))
        .to eq([/^\/first\/?$/, /^\/second\/?$/, /^\/third\/?$/, /^\/fourth\/?$/,
          /^\/fifth\/?/, /^\/sixth\/?$/, /^\/seventh\/?$/, /^\/eighth\/?$/, /^\/ninth/])
    end

    it "should handle a combination of strings, regexps, and arrays" do
      str = '/one,/two/three,/four'
      regexp1 = /\/between\//
      regexp2 = /\/ending\/?$/
      arr = ['/fifth/sixth,/seventh', '/eighth', /^\/ninth$/]
      filter = Rack::RestrictAccess::Filter.new
      filter.resources(str, regexp1, arr, regexp2, delimiter: ',')
      expect(filter.instance_variable_get(:@resources))
        .to eq([/^\/one\/?$/, /^\/two\/three\/?$/, /^\/four\/?$/,
          /\/between\//, /^\/fifth\/sixth\/?$/, /^\/seventh\/?$/, /^\/eighth\/?$/, /^\/ninth$/,
          /\/ending\/?$/])
    end

    it "should continue to add to @resources if called repeatedly" do
      str = '/home,/alone'
      reg = /^\/home2/
      arr = ['/cheers']
      filter = Rack::RestrictAccess::Filter.new
      filter.resources str, delimiter: ','
      filter.resources reg
      filter.resources arr
      expect(filter.instance_variable_get(:@resources))
        .to eq([/^\/home\/?$/, /^\/alone\/?$/, /^\/home2/, /^\/cheers\/?$/])
    end
  end

  describe "applies_to_resource?" do
    it "should return true if @applies_to_all_resources is true" do
      filter = Rack::RestrictAccess::Filter.new
      filter.instance_variable_set(:@applies_to_all_resources, true)
      expect(filter.applies_to_resource?('/some_path')).to be true
    end

    it "should return true if any @resources match requested_resource" do
      filter = Rack::RestrictAccess::Filter.new
      filter.instance_variable_set(:@resources, [/^\/admin$/])
      expect(filter.applies_to_resource?("/admin")).to be true
      expect(filter.applies_to_resource?("/admin/cp")).to be false
    end

    it "should return false if no @resources match requested_resource" do
      filter = Rack::RestrictAccess::Filter.new
      filter.instance_variable_set(:@resources, [/^\/admin$/, /^\/one$/, /^\/two$/])
      expect(filter.applies_to_resource?("/three")).to be false
    end

    it "should raise exception if argument cannot be converted to_str" do
      filter = Rack::RestrictAccess::Filter.new
      expect{filter.applies_to_resource?(9)}.to raise_exception(TypeError)
    end
  end

  describe "ip_to_regexp" do
    let(:filter) { Rack::RestrictAccess::Filter.new }

    it "should return the given input if it's already a regexp" do
      reg = /^192\.168\.\S*/
      expect(filter.ip_to_regexp(reg)).to eq(reg)
    end

    it "should convert string into regexp with anchors" do
      str = '192.168.0.1'
      expect(filter.ip_to_regexp(str)).to eq(/^192\.168\.0\.1$/)
    end

    it "should raise exception if argument does not respond to :match or :to_str" do
      expect{filter.ip_to_regexp(999)}.to raise_exception(TypeError)
    end
  end

  describe "origin_ips" do
    it "should call ip_to_regexp on given string and save the result to @ips" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@ips)).to be_empty
      ip = '192.168.0.1'
      filter.origin_ips(ip)
      expect(filter.instance_variable_get(:@ips)).to eq([/^192\.168\.0\.1$/])
    end

    it "should handle multiple strings" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@ips)).to be_empty
      ip1 = '0.0.0.0'
      ip2 = '192.168.1.1'
      ip3 = '192.168.1.2'
      filter.origin_ips(ip1, ip2, ip3)
      expect(filter.instance_variable_get(:@ips))
        .to eq([/^0\.0\.0\.0$/, /^192\.168\.1\.1$/, /^192\.168\.1\.2$/])
    end

    it "should handle delimited string when given delimiter string option" do
      csv = '192.168.1.1,192.168.1.2,192.168.1.3'
      filter2 = Rack::RestrictAccess::Filter.new
      expect(filter2.instance_variable_get(:@ips)).to be_empty
      filter2.origin_ips(csv, delimiter: ',')
      expect(filter2.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1$/, /^192\.168\.1\.2$/, /^192\.168\.1\.3$/])
    end

    it "should handle delimited string when given delimiter regexp option" do
      regexp_delimited = '192.168.1.1 | 192.168.1.2 | 192.168.1.3'
      filter3 = Rack::RestrictAccess::Filter.new
      expect(filter3.instance_variable_get(:@ips)).to be_empty
      filter3.origin_ips(regexp_delimited, delimiter: /[\s]*\|[\s]*/)
      expect(filter3.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1$/, /^192\.168\.1\.2$/, /^192\.168\.1\.3$/])
    end

    it "should not split string if no delimiter option is given" do
      not_delimited_csv = '192.168.1.1,192.168.1.2,192.168.1.3'
      filter1 = Rack::RestrictAccess::Filter.new
      expect(filter1.instance_variable_get(:@ips)).to be_empty
      filter1.origin_ips(not_delimited_csv)
      expect(filter1.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1,192\.168\.1\.2,192\.168\.1\.3$/])
    end

    it "should handle multiple delimited strings" do
      csv = "192.168.1.1, 192.168.1.2,192.168.1.3"
      tsv = "192.168.1.4\t192.168.1.5\t192.168.1.6"
      filter = Rack::RestrictAccess::Filter.new
      filter.origin_ips(csv, tsv, delimiter: /\s*,\s*|\t/)
      expect(filter.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1$/, /^192\.168\.1\.2$/, /^192\.168\.1\.3$/, /^192\.168\.1\.4$/, /^192\.168\.1\.5$/, /^192\.168\.1\.6$/])
    end

    it "should handle a regexp argument" do
      arg = /^192\.168\.\S*/
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@ips)).to be_empty
      filter.origin_ips(arg)
      expect(filter.instance_variable_get(:@ips)).to eq([/^192\.168\.\S*/])
    end

    it "should handle multiple regexps" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@ips)).to be_empty
      arg1 = /^192\.168\.\S*/
      arg2 = /^\d{3}\.168\.1\.1$/
      arg3 = /^193\.168\.\S*/
      filter.origin_ips(arg1, arg2, arg3)
      expect(filter.instance_variable_get(:@ips))
        .to eq([/^192\.168\.\S*/, /^\d{3}\.168\.1\.1$/, /^193\.168\.\S*/])
    end

    it "should handle single array of strings or regexps" do
      arr = ['192.168.1.1', /168\.1/, '192.168.1.3']
      filter = Rack::RestrictAccess::Filter.new
      filter.origin_ips(arr)
      expect(filter.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1$/, /168\.1/, /^192\.168\.1\.3$/])
    end

    it "should handle multiple arrays of strings or regexps" do
      arr1 = ['192.168.1.1', /168\.1/, '192.168.1.3']
      arr2 = [/\.1\.1$/, '192.168.1.4', /^192\.168\.1\.5$/]
      filter = Rack::RestrictAccess::Filter.new
      filter.origin_ips(arr1, arr2)
      expect(filter.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1$/, /168\.1/, /^192\.168\.1\.3$/, /\.1\.1$/, /^192\.168\.1\.4$/, /^192\.168\.1\.5$/])
    end

    it "should split strings in array if delimiter is given" do
      arr1 = ['192.168.1.1', '192.168.1.2,192.168.1.3', '192.168.1.4']
      arr2 = [/192\.168\.1\.5/, '192.168.1.6,192.168.1.7,192.168.1.8', /^192\.168\./]
      filter = Rack::RestrictAccess::Filter.new
      filter.origin_ips(arr1, arr2, delimiter: ',')
      expect(filter.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1$/, /^192\.168\.1\.2$/, /^192\.168\.1\.3$/, /^192\.168\.1\.4$/,
          /192\.168\.1\.5/, /^192\.168\.1\.6$/, /^192\.168\.1\.7$/, /^192\.168\.1\.8$/, /^192\.168\./])
    end

    it "should handle a combination of strings, regexps, and arrays" do
      str = '192.168.1.1,192.168.1.2,192.168.1.3'
      regexp1 = /192\.168/
      regexp2 = /\.168\.1\.$/
      arr = ['192.168.1.4,192.168.1.5', '192.168.1.6', /^199\S+$/]
      filter = Rack::RestrictAccess::Filter.new
      filter.origin_ips(str, regexp1, arr, regexp2, delimiter: ',')
      expect(filter.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1$/, /^192\.168\.1\.2$/, /^192\.168\.1\.3$/, /192\.168/,
          /^192\.168\.1\.4$/, /^192\.168\.1\.5$/, /^192\.168\.1\.6$/, /^199\S+$/, /\.168\.1\.$/])
    end

    it "should continue to add to @ips if called repeatedly" do
      str = '192.168.1.1,192.168.1.2'
      reg = /^192\.168\./
      arr = ['192.168.1.3']
      filter = Rack::RestrictAccess::Filter.new
      filter.origin_ips str, delimiter: ','
      filter.origin_ips reg
      filter.origin_ips arr
      expect(filter.instance_variable_get(:@ips))
        .to eq([/^192\.168\.1\.1$/, /^192\.168\.1\.2$/, /^192\.168\./, /^192\.168\.1\.3$/])
    end
  end

  describe "applies_to_ip?" do
    it "should return true if any @ips match remote_addr" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@ips)).to be_empty
      filter.instance_variable_set(:@ips, [/^192.168.0.1$/])
      expect(filter.applies_to_ip?('192.168.0.1')).to be true
    end

    it "should return false if no @ips match remote_addr" do
      filter = Rack::RestrictAccess::Filter.new
      expect(filter.instance_variable_get(:@ips)).to be_empty
      filter.instance_variable_set(:@ips, [/^192.168.0.1$/])
      expect(filter.applies_to_ip?('192.168.1.1')).to be false
    end

    it "should raise exception if argument cannot be coerced to_str" do
      filter = Rack::RestrictAccess::Filter.new
      expect{filter.applies_to_ip?(9001)}.to raise_exception(TypeError)
    end
  end
end
