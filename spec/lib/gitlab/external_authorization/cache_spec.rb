require 'spec_helper'

describe Gitlab::ExternalAuthorization::Cache, :clean_gitlab_redis_cache do
  let(:user) { build_stubbed(:user) }
  let(:cache_key) { "external_authorization:user-#{user.id}:label-dummy_label" }

  subject(:cache) { described_class.new(user, 'dummy_label') }

  def read_from_redis(key)
    Gitlab::Redis::Cache.with do |redis|
      redis.hget(cache_key, key)
    end
  end

  def set_in_redis(key, value)
    Gitlab::Redis::Cache.with do |redis|
      redis.hmset(cache_key, key, value)
    end
  end

  describe '#load' do
    it 'reads stored info from redis' do
      Timecop.freeze do
        set_in_redis(:access, false)
        set_in_redis(:reason, 'Access denied for now')
        set_in_redis(:refreshed_at, Time.now)

        access, reason, refreshed_at = cache.load

        expect(access).to eq(false)
        expect(reason).to eq('Access denied for now')
        expect(refreshed_at).to be_within(1.second).of(Time.now)
      end
    end
  end

  describe '#store' do
    it 'sets the values in redis' do
      Timecop.freeze do
        cache.store(true, 'the reason', Time.now)

        expect(read_from_redis(:access)).to eq('true')
        expect(read_from_redis(:reason)).to eq('the reason')
        expect(read_from_redis(:refreshed_at)).to eq(Time.now.to_s)
      end
    end
  end
end
