module Locksmith
  module Config
    extend self

    def env(key)
      ENV[key]
    end

    def env!(key)
      env(key) || raise("Locksmith is missing #{key}")
    end

    def env?(key)
      !env(key).nil?
    end

    def pg_lock_space
      n = "LOCKSMITH_PG_LOCK_SPACE"
      env(n) && env(n).to_i
    end

    def aws_id
      @aws_id ||= env!("AWS_ID")
    end

    def aws_secret
      @aws_secret ||= env!("AWS_SECRET")
    end

    def aws_id=(value); @aws_id = value; end
    def aws_secret=(value); @aws_secret = value; end

    def consul_host
      @consul_host ||= env!("CONSUL_HOST")
    end

    # Optional argument
    def consul_acl_token
      if ENV.has_key? 'CONSUL_ACL_TOKEN'
        @consul_acl_token = ENV['CONSUL_ACL_TOKEN']
      else
        @consul_acl_token = nil
      end
    end

    def consul_host=(value); @consul_host = value; end
    def consul_acl_token=(value); @consul_acl_token = value; end
  end
end
