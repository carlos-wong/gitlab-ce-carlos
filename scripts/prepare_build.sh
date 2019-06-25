. scripts/utils.sh

export SETUP_DB=${SETUP_DB:-true}
export USE_BUNDLE_INSTALL=${USE_BUNDLE_INSTALL:-true}
export BUNDLE_INSTALL_FLAGS="--without=production --jobs=$(nproc) --path=vendor --retry=3 --quiet"

if [ "$USE_BUNDLE_INSTALL" != "false" ]; then
  bundle --version
  bundle install --clean $BUNDLE_INSTALL_FLAGS && bundle check
fi

# Only install knapsack after bundle install! Otherwise oddly some native
# gems could not be found under some circumstance. No idea why, hours wasted.
retry gem install knapsack --no-document

cp config/gitlab.yml.example config/gitlab.yml
sed -i 's/bin_path: \/usr\/bin\/git/bin_path: \/usr\/local\/bin\/git/' config/gitlab.yml

# Determine the database by looking at the job name.
# This would make the default database postgresql.
if [[ "${CI_JOB_NAME#*mysql}" != "$CI_JOB_NAME" ]]; then
  export GITLAB_DATABASE='mysql'
else
  export GITLAB_DATABASE='postgresql'
fi

cp config/database.yml.$GITLAB_DATABASE config/database.yml

if [ -f config/database_geo.yml.$GITLAB_DATABASE ]; then
  cp config/database_geo.yml.$GITLAB_DATABASE config/database_geo.yml
fi

# Set user to a non-superuser to ensure we test permissions
sed -i 's/username: root/username: gitlab/g' config/database.yml

if [ "$GITLAB_DATABASE" = 'postgresql' ]; then
  sed -i 's/localhost/postgres/g' config/database.yml

  if [ -f config/database_geo.yml ]; then
    sed -i 's/localhost/postgres/g' config/database_geo.yml
  fi
else # Assume it's mysql
  sed -i 's/localhost/mysql/g' config/database.yml

  if [ -f config/database_geo.yml ]; then
    sed -i 's/localhost/mysql/g' config/database_geo.yml
  fi
fi

cp config/resque.yml.example config/resque.yml
sed -i 's/localhost/redis/g' config/resque.yml

cp config/redis.cache.yml.example config/redis.cache.yml
sed -i 's/localhost/redis/g' config/redis.cache.yml

cp config/redis.queues.yml.example config/redis.queues.yml
sed -i 's/localhost/redis/g' config/redis.queues.yml

cp config/redis.shared_state.yml.example config/redis.shared_state.yml
sed -i 's/localhost/redis/g' config/redis.shared_state.yml

if [ "$SETUP_DB" != "false" ]; then
  setup_db
elif getent hosts postgres || getent hosts mysql; then
  setup_db_user_only
fi
