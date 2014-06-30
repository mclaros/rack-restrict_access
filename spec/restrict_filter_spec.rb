require 'spec_helper'

describe Rack::RestrictAccess::RestrictFilter do
  it "should inherit from Filter" do
    expect(Rack::RestrictAccess::RestrictFilter.superclass).to eq(Rack::RestrictAccess::Filter)
  end

  describe "initialize" do
    it "should set defaults" do
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new
      expect(restrict_filter.instance_variable_get(:@ips)).to eq([])
      expect(restrict_filter.instance_variable_get(:@resources)).to eq([])
      expect(restrict_filter.instance_variable_get(:@credentials)).to eq([])
    end
  end

  describe "credentials" do
    it "should do nothing if given no arguments" do
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new do
        credentials
      end
      expect(restrict_filter.instance_variable_get(:@credentials))
        .to eq([])
    end

    it "should save hash of username password pair to @credentials" do
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new do
        credentials(username: 'admin', password: 'pass123')
      end
      expect(restrict_filter.instance_variable_get(:@credentials))
        .to eq([{username: /^admin$/, password: /^pass123$/}])
    end

    it "should accept regexp values" do
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new do
        credentials(username: /admin$/, password: /^pass/)
      end
      expect(restrict_filter.instance_variable_get(:@credentials))
        .to eq([{username: /admin$/, password: /^pass/}])
    end

    it "should handle multiple hashes" do
      creds1 = {username: 'u1', password: 'pass1'}
      creds2 = {username: 'u2', password: 'pass2'}
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new do
        credentials creds1, creds2
      end
      expect(restrict_filter.instance_variable_get(:@credentials))
        .to eq([{username: /^u1$/, password: /^pass1$/}, {username: /^u2$/, password: /^pass2$/}])
    end

    it "should handle an array of hashes" do
      cred_hashes = []
      cred_hashes << {username: 'u1', password: 'pass1'}
      cred_hashes << {username: /u2/, password: /pass2/}
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new do
        credentials cred_hashes
      end
      expect(restrict_filter.instance_variable_get(:@credentials))
        .to eq([{username: /^u1$/, password: /^pass1$/}, {username: /u2/, password: /pass2/}])
    end

    it "should handle delimited strings" do
      simple_string = 'uname,pass'
      restrict_filter1 = Rack::RestrictAccess::RestrictFilter.new do
        credentials simple_string
      end
      expect(restrict_filter1.instance_variable_get(:@credentials))
        .to eq([{username: /^uname$/, password: /^pass$/}])

      longer_string = 'user1,pass1;user2,pass2'
      restrict_filter2 = Rack::RestrictAccess::RestrictFilter.new do
        credentials longer_string
      end
      expect(restrict_filter2.instance_variable_get(:@credentials))
        .to eq([{username: /^user1$/, password: /^pass1$/}, {username: /^user2$/, password: /^pass2$/}])

      complex_string = 'username1:password1 | username2 : password2|username3:password3'
      restrict_filter3 = Rack::RestrictAccess::RestrictFilter.new do
        credentials complex_string, credentials_delimiter: /\s*:\s*/, credential_pair_delimiter: /\s*\|\s*/
      end
      expect(restrict_filter3.instance_variable_get(:@credentials))
        .to eq([{username: /^username1$/, password: /^password1$/}, {username: /^username2$/, password: /^password2$/}, {username: /^username3$/, password: /^password3$/}])
    end

    it "should handle multiple delimited strings" do
      simple_string = 'uname,pass'
      longer_string = 'user1,pass1;user2,pass2'
      longest_string = 'username1,password1;username2,password2;username3,password3'
      restrict_filter3 = Rack::RestrictAccess::RestrictFilter.new do
        credentials simple_string, longer_string, longest_string
      end
      expect(restrict_filter3.instance_variable_get(:@credentials))
        .to eq([{username: /^uname$/, password: /^pass$/},
          {username: /^user1$/, password: /^pass1$/}, {username: /^user2$/, password: /^pass2$/},
          {username: /^username1$/, password: /^password1$/}, {username: /^username2$/, password: /^password2$/}, {username: /^username3$/, password: /^password3$/}])
    end

    it "should handle an array of delimited strings and/or hashes" do
      arr = []
      arr << 'uname,pass'
      arr << 'user1,pass1;user2,pass2'
      arr << 'username1,password1;username2,password2;username3,password3'
      restrict_filter3 = Rack::RestrictAccess::RestrictFilter.new do
        credentials arr
      end
      expect(restrict_filter3.instance_variable_get(:@credentials))
        .to eq([{username: /^uname$/, password: /^pass$/},
          {username: /^user1$/, password: /^pass1$/}, {username: /^user2$/, password: /^pass2$/},
          {username: /^username1$/, password: /^password1$/}, {username: /^username2$/, password: /^password2$/}, {username: /^username3$/, password: /^password3$/}])
    end

    it "should handle multiple arrays of delimited strings/hashes" do
      arr1 = []
      arr1 << 'uname,pass'
      arr1 << 'user1,pass1;user2,pass2'
      arr1 << 'username1,password1;username2,password2;username3,password3'

      arr2 = []
      arr2 << 'uname2,pass2'
      arr2 << 'user21,pass21;user22,pass22'
      arr2 << 'username21,password21;username22,password22;username23,password23'
      restrict_filter3 = Rack::RestrictAccess::RestrictFilter.new do
        credentials arr1, arr2
      end
      expect(restrict_filter3.instance_variable_get(:@credentials))
        .to eq([{username: /^uname$/, password: /^pass$/},
          {username: /^user1$/, password: /^pass1$/}, {username: /^user2$/, password: /^pass2$/},
          {username: /^username1$/, password: /^password1$/}, {username: /^username2$/, password: /^password2$/}, {username: /^username3$/, password: /^password3$/},
          {username: /^uname2$/, password: /^pass2$/},
          {username: /^user21$/, password: /^pass21$/}, {username: /^user22$/, password: /^pass22$/},
          {username: /^username21$/, password: /^password21$/}, {username: /^username22$/, password: /^password22$/}, {username: /^username23$/, password: /^password23$/}])
    end

    it "should continue to add to @credentials if called repeatedly" do
      arr1 = []
      arr1 << 'uname,pass'
      arr1 << 'user1,pass1;user2,pass2'
      arr1 << 'username1,password1;username2,password2;username3,password3'

      arr2 = []
      arr2 << 'uname2,pass2'
      arr2 << 'user21,pass21;user22,pass22'
      arr2 << 'username21,password21;username22,password22;username23,password23'
      restrict_filter3 = Rack::RestrictAccess::RestrictFilter.new do
        credentials arr1
      end
      restrict_filter3.credentials arr2
      expect(restrict_filter3.instance_variable_get(:@credentials))
        .to eq([{username: /^uname$/, password: /^pass$/},
          {username: /^user1$/, password: /^pass1$/}, {username: /^user2$/, password: /^pass2$/},
          {username: /^username1$/, password: /^password1$/}, {username: /^username2$/, password: /^password2$/}, {username: /^username3$/, password: /^password3$/},
          {username: /^uname2$/, password: /^pass2$/},
          {username: /^user21$/, password: /^pass21$/}, {username: /^user22$/, password: /^pass22$/},
          {username: /^username21$/, password: /^password21$/}, {username: /^username22$/, password: /^password22$/}, {username: /^username23$/, password: /^password23$/}])
    end
  end

  describe "credentials_match?" do
    it "should return true if @credentials contains given username, password pair" do
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new do
        credentials({username: 'admin1', password: 'hard_to_guess'}, {username: 'admin2', password: 'hard_to_guess2'})
      end
      expect(restrict_filter.credentials_match?(username: 'admin2', password: 'hard_to_guess2')).to be true
    end

    it "should return false if @credentials does not contain given username, password pair" do
      restrict_filter = Rack::RestrictAccess::RestrictFilter.new do
        credentials(username: 'admin1', password: 'hard_to_guess')
      end
      expect(restrict_filter.credentials_match?(username: 'adminfalse', password: 'hard_to_guess2')).to be false
      expect(restrict_filter.credentials_match?(username: 'admin2', password: '')).to be false
    end
  end
end
