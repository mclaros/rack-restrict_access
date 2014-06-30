require 'spec_helper'

describe Rack::RestrictAccess do
  describe "initialize" do
    it "should save the app as an instance variable" do
      fake_app = double("app")
      rs = Rack::RestrictAccess.new(fake_app)
      expect(rs.instance_variable_get(:@app)).to eq(fake_app)
    end

    it "should set default @options" do
      fake_app = double("app")
      rs = Rack::RestrictAccess.new(fake_app)
      expect(rs.instance_variable_get(:@options)).to eq({enabled: true, auth: true})
    end

    it "should execute block if given" do
      expect_any_instance_of(Rack::RestrictAccess).to receive(:some_method)
      fake_app = double("app")
      Rack::RestrictAccess.new(fake_app) do
        some_method
      end
    end
  end

  describe "options" do
    it "should override current options" do
      fake_app = double("app")
      rs = Rack::RestrictAccess.new(fake_app) do
        options auth: false
      end
      expect(rs.instance_variable_get(:@options)).to eq({enabled: true, auth: false})
    end
  end

  describe "block" do
    let (:fake_app) { double("app") }

    it "should add a BlockFilter to block_filters" do
      rs1 = Rack::RestrictAccess.new(fake_app)
      expect(rs1.send(:block_filters)).to be_empty
      rs1.block do
      end
      expect(rs1.send(:block_filters).length).to eq(1)
      expect(rs1.send(:block_filters).all? {|f| f.is_a? Rack::RestrictAccess::BlockFilter }).to be true

      rs2 = Rack::RestrictAccess.new(fake_app) do
        block do
        end
      end
      expect(rs2.send(:block_filters).length).to eq(1)
      expect(rs2.send(:block_filters).all? {|f| f.is_a? Rack::RestrictAccess::BlockFilter }).to be true
    end

    it "should call given block on new BlockFilter" do
      expect_any_instance_of(Rack::RestrictAccess::BlockFilter).to receive(:bogus_method)
      Rack::RestrictAccess.new(fake_app) do
        block do
          bogus_method
        end
      end
    end

    it "should continue to add BlockFilters to block_filters if called repeatedly" do
      rs = Rack::RestrictAccess.new(fake_app)
      expect(rs.send(:block_filters)).to be_empty
      rs.block do
      end
      expect(rs.send(:block_filters).length).to eq(1)
      expect(rs.send(:block_filters).all? {|f| f.is_a? Rack::RestrictAccess::BlockFilter }).to be true

      rs.block do
      end
      expect(rs.send(:block_filters).length).to eq(2)
      expect(rs.send(:block_filters).all? {|f| f.is_a? Rack::RestrictAccess::BlockFilter }).to be true
    end
  end

  describe "restrict" do
    let (:fake_app) { double("app") }

    it "should add a RestrictFilter to restrict_filters" do
      rs1 = Rack::RestrictAccess.new(fake_app)
      expect(rs1.send(:restrict_filters)).to eq([])
      rs1.restrict do
      end
      expect(rs1.send(:restrict_filters).length).to eq(1)
      expect(rs1.send(:restrict_filters).all? {|f| f.is_a? Rack::RestrictAccess::RestrictFilter }).to be true

      rs2 = Rack::RestrictAccess.new(fake_app) do
        restrict do
        end
      end
      expect(rs2.send(:restrict_filters).length).to eq(1)
      expect(rs2.send(:restrict_filters).all? {|f| f.is_a? Rack::RestrictAccess::RestrictFilter }).to be true
    end

    it "should call given block on new RestrictFilter" do
      expect_any_instance_of(Rack::RestrictAccess::RestrictFilter).to receive(:bogus_method)
      Rack::RestrictAccess.new(fake_app) do
        restrict do
          bogus_method
        end
      end
    end

    it "should continue to add RestrictFilters to restrict_filters if called repeatedly" do
      rs = Rack::RestrictAccess.new(fake_app)
      expect(rs.send(:restrict_filters)).to be_empty
      rs.restrict do
      end
      expect(rs.send(:restrict_filters).length).to eq(1)
      expect(rs.send(:restrict_filters).all? {|f| f.is_a? Rack::RestrictAccess::RestrictFilter }).to be true

      rs.restrict do
      end
      expect(rs.send(:restrict_filters).length).to eq(2)
      expect(rs.send(:restrict_filters).all? {|f| f.is_a? Rack::RestrictAccess::RestrictFilter }).to be true
    end
  end

  describe "call" do
    let(:fake_app) { double("app") }
    it "should allow access by default" do
      rs = Rack::RestrictAccess.new(fake_app)
      expect(rs.send(:block_filters)).to eq([])
      expect(rs.send(:allow_filters)).to eq([])
      expect(rs.send(:restrict_filters)).to eq([])
      expect(fake_app).to receive(:call).and_return([200, {"Content-Type" => "text/html"}, ["body"]])
      expect(rs.call({})).to eq([200, {"Content-Type" => "text/html"}, ["body"]])
    end

    it "should block access when a BlockFilter applies to given path" do
      env = {'PATH_INFO' => '/admin'}
      rs = Rack::RestrictAccess.new(fake_app) do
        block do
          resources '/admin'
        end
      end
      expect(rs.call(env)).to eq([403, {"Content-Type" => "text/html"}, ["<h1>Forbidden</h1>"]])

      rs2 = Rack::RestrictAccess.new(fake_app) do
        block do
          all_resources!
        end
      end
      expect(rs2.call(env)).to eq([403, {"Content-Type" => "text/html"}, ["<h1>Forbidden</h1>"]])
    end

    it "should block access when a BlockFilter applies to origin ip" do
      env = {'REMOTE_ADDR' => '192.168.0.1'}
      rs = Rack::RestrictAccess.new(fake_app) do
        block do
          origin_ips '192.168.0.1'
        end
      end
      expect(rs.call(env)).to eq([403, {"Content-Type" => "text/html"}, ["<h1>Forbidden</h1>"]])
    end

    it "should restrict access when a RestrictFilter applies to given path" do
      env = {'PATH_INFO' => '/admin'}
      rs = Rack::RestrictAccess.new(fake_app) do
        restrict do
          resources '/admin'
          credentials username: 'admin', password: 'pass'
        end
      end
      expect(rs.call(env)).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"0", "WWW-Authenticate"=>"Basic realm=\"\""}, []])
    end

    it "should restrict access when a RestrictFilter applies to origin ip" do
      env = {'REMOTE_ADDR' => '192.168.0.1'}
      rs = Rack::RestrictAccess.new(fake_app) do
        restrict do
          origin_ips '192.168.0.1'
          credentials username: 'admin', password: 'pass'
        end
      end
      expect(rs.call(env)).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"0", "WWW-Authenticate"=>"Basic realm=\"\""}, []])
    end

    it "should not restrict access when RestrictFilter does not have any credentials to compare" do
      env = {"PATH_INFO" => "/admin"}
      rs = Rack::RestrictAccess.new(fake_app) do
        restrict do
          all_resources!
        end
      end
      expect(fake_app).to receive(:call).with(env).and_return([200, {"Content-Type" => "text/html"}, ["body"]])
      expect(rs.call(env)).to eq([200, {"Content-Type" => "text/html"}, ["body"]])
    end

    it "shoud not restrict access when @options[:auth_enabled] is not true" do
      env = {"PATH_INFO" => "/admin"}
      rs = Rack::RestrictAccess.new(fake_app) do
        restrict do
          all_resources!
        end
      end
      expect(fake_app).to receive(:call).and_return([200, {"Content-Type" => "text/html"}, ["body"]])
      expect(rs.call(env)).to eq([200, {"Content-Type" => "text/html"}, ["body"]])
    end

    it "should allow access when an AllowFilter applies to given path" do
      env = {"PATH_INFO" => "/admin"}
      expect(fake_app).to receive(:call).with(env).exactly(2).times.and_return([200, {"Content-Type" => "text/html"}, ["body"]])
      rs1 = Rack::RestrictAccess.new(fake_app) do
        block do
          all_resources!
        end

        restrict do
          all_resources!
        end

        allow do
          resources "/admin"
        end
      end
      expect(rs1.call(env)).to eq([200, {"Content-Type" => "text/html"}, ["body"]])

      rs2 = Rack::RestrictAccess.new(fake_app) do
        block do
          all_resources!
        end

        restrict do
          all_resources!
        end

        allow do
          all_resources!
        end
      end
      expect(rs2.call(env)).to eq([200, {"Content-Type" => "text/html"}, ["body"]])
    end

    it "should allow access when an AllowFilter applies to origin ip" do
      env = {"REMOTE_ADDR" => "192.168.0.1"}
      expect(fake_app).to receive(:call).with(env).and_return([200, {"Content-Type" => "text/html"}, ["body"]])
      rs1 = Rack::RestrictAccess.new(fake_app) do
        block do
          all_resources!
        end

        restrict do
          all_resources!
        end

        allow do
          origin_ips "192.168.0.1"
        end
      end
      expect(rs1.call(env)).to eq([200, {"Content-Type" => "text/html"}, ["body"]])
    end

    it "should follow the following precedence: AllowFilters > BlockFilters > RestrictFilters" do
      env = {"REMOTE_ADDR" => "192.168.0.1", "PATH_INFO" => "/admin"}
      success_response = [200, {"Content-Type" => "text/html"}, ["body"]]
      blocked_response = [403, {"Content-Type" => "text/html"}, ["<h1>Forbidden</h1>"]]
      restricted_response = [401, {"Content-Type"=>"text/plain", "Content-Length"=>"0", "WWW-Authenticate"=>"Basic realm=\"\""}, []]
      expect(fake_app).to receive(:call).with(env).exactly(1).times.and_return(success_response)

      allow_rs = Rack::RestrictAccess.new(fake_app) do
        block do
          all_resources!
        end

        restrict do
          all_resources!
        end

        allow do
          all_resources!
        end
      end
      expect(allow_rs.call(env)).to eq(success_response)

      block_rs = Rack::RestrictAccess.new(fake_app) do
        restrict do
          all_resources!
        end

        block do
          all_resources!
        end
      end
      expect(block_rs.call(env)).to eq(blocked_response)

      restrict_rs = Rack::RestrictAccess.new(fake_app) do
        restrict do
          all_resources!
          credentials username: 'user', password: '123'
        end
      end
      expect(restrict_rs.call(env)).to eq(restricted_response)
    end

    it "should allow access if @options[:enabled] is false" do
      rs = Rack::RestrictAccess.new(fake_app) do
        options enabled: false
        block do
          all_resources!
        end
      end
      expect(rs.instance_variable_get(:@options)[:enabled]).to be false
      expect(fake_app).to receive(:call).and_return([200, {"Content-Type" => "text/html"}, ["body"]])
      expect(rs.call({})).to eq([200, {"Content-Type" => "text/html"}, ["body"]])
    end
  end
end
