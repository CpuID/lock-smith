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
      Diplomat::Lock.release("/locks/#{name}", diplomat_session)
    end

    def diplomat_session
      @consul_lock.synchronize do
        Diplomat.configure do |config|
          config.url = Config.consul_host
          config.acl_token = Config.consul_acl_token unless Config.consul_acl_token.nil?
        end
        @diplomat_session ||= Diplomat::Session.create({
          :Node => Socket.gethostname,
          :Name => 'lock-smith',
          :TTL  => @ttl
        })
      end
      return @diplomat_session
    end

  end
end