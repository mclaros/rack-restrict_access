require "rack"
require "rack/restrict_access/version"

module Rack
  class RestrictAccess
    def initialize(app, &blk)
      @app = app
      @options = {enabled: true, auth: true}

      if block_given?
        instance_eval(&blk)
      end
    end

    def options(options_hash)
      @options.merge!(options_hash)
    end

    def app_enabled?
      @options[:enabled] == true
    end

    def auth_enabled?
      @options[:auth] == true
    end

    def block(&blk)
      filter = BlockFilter.new
      block_filters << filter
      filter.instance_eval(&blk)
    end

    def restrict(&blk)
      filter = RestrictFilter.new
      restrict_filters << filter
      filter.instance_eval(&blk)
    end

    def allow(&blk)
      filter = AllowFilter.new
      allow_filters << filter
      filter.instance_eval(&blk)
    end

    def call(env)
      return success_response(env) unless app_enabled?
      request = Rack::Request.new(env)
      path = request.path
      origin = request.ip

      exception =  allow_filters.detect { |filter| filter.allows_resource?(path) || filter.allows_ip?(origin) }
      return success_response(env) if exception

      blocker = block_filters.detect { |filter| filter.blocks_resource?(path) || filter.blocks_ip?(origin) }
      return blocked_response(blocker) if blocker

      if auth_enabled?
        restrictor = restrict_filters.detect { |filter| filter.restricts_resource?(path) || filter.restricts_ip?(origin) }
        return restricted_response(env, restrictor) if restrictor && restrictor.credentials_count > 0
      end

      success_response(env)
    end

    private
      def block_filters
        @block_filters ||= []
      end

      def restrict_filters
        @restrict_filters ||= []
      end

      def allow_filters
        @allow_filters ||= []
      end

      def success_response(env)
        @app.call(env)
      end

      def blocked_response(block_filter)
        content_type = {"Content-Type" => "text/html"}
        body = block_filter.instance_variable_get(:@body)
        code = block_filter.instance_variable_get(:@status_code)
        [code, content_type, body]
      end

      def restricted_response(env, restrict_filter)
        auth = Rack::Auth::Basic.new(@app) do |uname, pass|
          restrict_filter.credentials_match?(username: uname, password: pass)
        end
        auth.call(env)
      end

      class Filter
        attr_reader :filter_type

        def initialize(&blk)
          @ips = []
          @resources = []
          @applies_to_all_resources = false

          if block_given?
            instance_eval(&blk)
          end
        end

        def applies_to_resource?(requested_resource)
          return true if @applies_to_all_resources
          raise TypeError, requested_resource unless requested_resource.respond_to? :to_str
          requested_resource = requested_resource.to_str
          @resources.any? do |resource|
            !(requested_resource =~ resource).nil?
          end
        end

        def applies_to_ip?(remote_addr)
          raise TypeError, remote_addr unless remote_addr.respond_to? :to_str
          remote_addr = remote_addr.to_str
          @ips.any? do |ip|
            !(remote_addr =~ ip).nil?
          end
        end

        def path_to_regexp(path)
          if path.respond_to? :to_str
            /^#{Regexp.escape(path)}\/?$/
          elsif path.respond_to? :match
            path
          else
            raise TypeError, path
          end
        end

        def all_resources!
          @applies_to_all_resources = true
        end

        def resources(*paths)
          options = paths.pop if paths.last.is_a? Hash
          options ||= {}
          delimiter = options.fetch(:delimiter, false)

          concat_new_attributes(args: paths, ivar: @resources) do |path|
            path = path.split(delimiter) if delimiter && path.is_a?(String)
            if path.is_a? Array
              path.map! { |pt| path_to_regexp(pt) }
            else
              path_to_regexp(path)
            end
          end
        end

        def ip_to_regexp(ip)
          if ip.respond_to? :to_str
            /^#{Regexp.escape(ip)}$/
          elsif ip.respond_to? :match
            ip
          else
            raise TypeError, ip
          end
        end

        def origin_ips(*ips)
          options = ips.pop if ips.last.is_a? Hash
          options ||= {}
          delimiter = options.fetch(:delimiter, false)

          concat_new_attributes(args: ips, ivar: @ips) do |ip|
            ip = ip.split(delimiter) if delimiter && ip.is_a?(String)
            if ip.is_a? Array
              ip.map! { |addr| ip_to_regexp(addr) }
            else
              ip_to_regexp(ip)
            end
          end
        end

        private
          def concat_new_attributes(options, &blk)
            args = options.fetch(:args, [])
            ivar = options.fetch(:ivar, nil)
            raise ArgumentError, "Missing :ivar option" unless ivar
            values_to_save = args.flatten.map do |arg|
              blk.call(arg)
            end.flatten
            ivar.concat(values_to_save)
          end
      end

      class AllowFilter < Filter
        def allows_resource?(resource)
          applies_to_resource?(resource)
        end

        def allows_ip?(ip)
          applies_to_ip?(ip)
        end
      end

      class BlockFilter < Filter
        def initialize
          @status_code = 403
          @body = ["<h1>Forbidden</h1>"]
          super
        end

        def body(enumerable)
          raise ArgumentError, "Body must respond to #each" unless enumerable.respond_to? :each
          @body = enumerable
        end

        def status_code(int)
          @status_code = int.to_i
        end

        def blocks_resource?(path)
          applies_to_resource?(path)
        end

        def blocks_ip?(ip)
          applies_to_ip?(ip)
        end
      end

      class RestrictFilter < Filter
        def initialize
          @credentials = []
          super
        end

        def restricts_resource?(path)
          applies_to_resource?(path)
        end

        def restricts_ip?(ip)
          applies_to_ip?(ip)
        end

        def credentials(*creds)
          if !creds.first.is_a?(Hash) && creds.last.is_a?(Hash)
            options = creds.pop
          end
          options ||= {}

          concat_new_attributes(args: creds, ivar: @credentials) do |credential_pair|
            if credential_pair.is_a? Hash
              creds_from_hash(credential_pair)
            elsif credential_pair.is_a? String
              creds_from_string(credential_pair, options)
            elsif credential_pair.is_a? Array
              creds_from_array(credential_pair, options)
            end
          end
        end

        def credentials_match?(creds_hash)
          @credentials.any? do |saved_hash|
            saved_u = saved_hash[:username]
            saved_p = saved_hash[:password]
            given_u = creds_hash[:username]
            given_p = creds_hash[:password]
            !(given_u =~ saved_u).nil? && !(given_p =~ saved_p).nil?
          end
        end

        def credentials_count
          @credentials.length
        end

        private
          def cred_to_regexp(cred)
            if cred.respond_to? :to_str
              /^#{Regexp.escape(cred)}$/
            elsif cred.respond_to? :match
              cred
            else
              raise TypeError, cred
            end
          end

          def creds_from_hash(hash)
            {
              username: cred_to_regexp(hash[:username]),
              password: cred_to_regexp(hash[:password])
            }
          end

          def creds_from_array(array)
            array.map do |el|
              creds_from_string(el, options)
            end
          end

          def creds_from_string(string, options = {})
            string = string.to_str
            credentials_delimiter = options.fetch(:credentials_delimiter, ',')
            credential_pair_delimiter = options.fetch(:credential_pair_delimiter, ';')
            creds = string.split(credential_pair_delimiter)
            creds.map do |str|
              cred_pair = str.split(credentials_delimiter)
              {
                username: cred_to_regexp(cred_pair[0]),
                password: cred_to_regexp(cred_pair[1])
              }
            end
          end
      end

  end
end

