require 'diplomat'
require 'socket'
require 'timeout'
require 'thread'
require 'locksmith/config'

module Locksmith
  module Consul
    extend self
    # This module is safe for threads.
    @consul_lock = Mutex.new
    @ttl = 60
    @existing_diplomat_session_expire = nil

    def logger
      @logger ||= Logger.new(STDOUT)
      return @logger
    end

    def lock(name, opts={})
      opts[:ttl] ||= 60
      opts[:attempts] ||= 3
      @ttl = opts[:ttl]

      if create(name, opts[:attempts])
        begin Timeout::timeout(opts[:ttl]) {return(yield)}
        ensure delete(name)
        end
      end
    end

    def create(name, attempts)
      attempts.times do |i|
        begin
          logger.info "Acquiring Lock: /locks/#{name}"
          lock_acquired = Diplomat::Lock.acquire("/locks/#{name}", diplomat_session)
          if lock_acquired == true
            return(true)
          else
            return(false)
          end
        end
      end
      return(false)
    end

    def delete(name)
      logger.info "Releasing Lock: /locks/#{name}"
      Diplomat::Lock.release("/locks/#{name}", diplomat_session)
    end

    def diplomat_session
      consul_host = Config.consul_host
      raise 'Consul Host should be specified in the format hostname:port, no protocol required.' if consul_host.match(/:\/\//)
      consul_host = "http://#{consul_host}"
      raise 'TTL must be an numeric value in seconds (no decimals)' unless @ttl.to_s.match(/^[0-9]+$/)
      @consul_lock.synchronize do
        Diplomat.configure do |config|
          config.url = consul_host
          config.acl_token = Config.consul_acl_token unless Config.consul_acl_token.nil?
        end
        unless @existing_diplomat_session_expire.nil?
          # Get a new one if we are within 5 seconds of the previous one, to be safe.
          if @existing_diplomat_session_expire <= (Time.now.to_i - 5)
            @diplomat_session = nil
            @existing_diplomat_session_expire = nil
            logger.info "Previous Consul session expired."
          end
        end
        logger.info "Current Consul Session: #{@diplomat_session}"
        @diplomat_session ||= Diplomat::Session.create({
          :Name => 'lock-smith',
          :TTL  => "#{@ttl}s"
        })
        logger.info "New Consul Session: #{@diplomat_session}"
        @existing_diplomat_session_expire = Time.now.to_i + @ttl.to_i
      end
      return @diplomat_session
    end

  end
end
