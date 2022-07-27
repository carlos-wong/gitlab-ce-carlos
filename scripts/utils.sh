function retry() {
  if eval "$@"; then
    return 0
  fi

  for i in 2 1; do
    sleep 3s
    echo "Retrying $i..."
    if eval "$@"; then
      return 0
    fi
  done
  return 1
}

function test_url() {
  local url="${1}"
  local status

  status=$(curl --output /dev/null -L -s -w ''%{http_code}'' "${url}")

  if [[ $status == "200" ]]; then
    return 0
  else
    # We display the error in the job to allow for better debugging
    curl -L --fail --output /dev/null "${url}"
    echo -e "\nExpected HTTP status 200: received ${status}\n"
    return 1
  fi
}

function bundle_install_script() {
  local extra_install_args="${1}"

  if [[ "${extra_install_args}" =~ "--without" ]]; then
    echoerr "The '--without' flag shouldn't be passed as it would replace the default \${BUNDLE_WITHOUT} (currently set to '${BUNDLE_WITHOUT}')."
    echoerr "Set the 'BUNDLE_WITHOUT' variable instead, e.g. '- export BUNDLE_WITHOUT=\"\${BUNDLE_WITHOUT}:any:other:group:not:to:install\"'."
    exit 1;
  fi;

  gem --version
  bundle --version
  gem install bundler --no-document --conservative --version 2.3.15
  test -d jh && bundle config set --local gemfile 'jh/Gemfile'
  bundle config set path "$(pwd)/vendor"
  bundle config set clean 'true'

  echo "${BUNDLE_WITHOUT}"
  bundle config

  run_timed_command "bundle install ${BUNDLE_INSTALL_FLAGS} ${extra_install_args} && bundle check"

  if [[ $(bundle info pg) ]]; then
    # When we test multiple versions of PG in the same pipeline, we have a single `setup-test-env`
    # job but the `pg` gem needs to be rebuilt since it includes extensions (https://guides.rubygems.org/gems-with-extensions).
    # Uncomment the following line if multiple versions of PG are tested in the same pipeline.
    run_timed_command "bundle pristine pg"
  fi
}

function setup_db_user_only() {
  source scripts/create_postgres_user.sh
}

function setup_db_praefect() {
  createdb -h postgres -U postgres --encoding=UTF8 --echo praefect_test
}

function setup_db() {
  run_timed_command "setup_db_user_only"
  run_timed_command_with_metric "bundle exec rake db:drop db:create db:schema:load db:migrate" "setup_db"
  run_timed_command "setup_db_praefect"
}

function install_api_client_dependencies_with_apk() {
  run_timed_command "apk add --update openssl curl jq"
}

function install_gitlab_gem() {
  run_timed_command "gem install httparty --no-document --version 0.18.1"
  run_timed_command "gem install gitlab --no-document --version 4.17.0"
}

function install_tff_gem() {
  run_timed_command "gem install test_file_finder --no-document --version 0.1.1"
}

function install_junit_merge_gem() {
  run_timed_command "gem install junit_merge --no-document --version 0.1.2"
}

function run_timed_command() {
  local cmd="${1}"
  local metric_name="${2:-no}"
  local timed_metric_file
  local start=$(date +%s)

  echosuccess "\$ ${cmd}"
  eval "${cmd}"

  local ret=$?
  local end=$(date +%s)
  local runtime=$((end-start))

  if [[ $ret -eq 0 ]]; then
    echosuccess "==> '${cmd}' succeeded in ${runtime} seconds."

    if [[ "${metric_name}" != "no" ]]; then
      timed_metric_file=$(timed_metric_file $metric_name)
      echo "# TYPE ${metric_name} gauge" > "${timed_metric_file}"
      echo "# UNIT ${metric_name} seconds" >> "${timed_metric_file}"
      echo "${metric_name} ${runtime}" >> "${timed_metric_file}"
    fi

    return 0
  else
    echoerr "==> '${cmd}' failed (${ret}) in ${runtime} seconds."
    return $ret
  fi
}

function run_timed_command_with_metric() {
  local cmd="${1}"
  local metric_name="${2}"
  local metrics_file=${METRICS_FILE:-metrics.txt}

  run_timed_command "${cmd}" "${metric_name}"

  local ret=$?

  cat $(timed_metric_file $metric_name) >> "${metrics_file}"

  return $ret
}

function timed_metric_file() {
  local metric_name="${1}"

  echo "$(pwd)/tmp/duration_${metric_name}.txt"
}

function echoerr() {
  local header="${2:-no}"

  if [ "${header}" != "no" ]; then
    printf "\n\033[0;31m** %s **\n\033[0m" "${1}" >&2;
  else
    printf "\033[0;31m%s\n\033[0m" "${1}" >&2;
  fi
}

function echoinfo() {
  local header="${2:-no}"

  if [ "${header}" != "no" ]; then
    printf "\n\033[0;33m** %s **\n\033[0m" "${1}" >&2;
  else
    printf "\033[0;33m%s\n\033[0m" "${1}" >&2;
  fi
}

function echosuccess() {
  local header="${2:-no}"

  if [ "${header}" != "no" ]; then
    printf "\n\033[0;32m** %s **\n\033[0m" "${1}" >&2;
  else
    printf "\033[0;32m%s\n\033[0m" "${1}" >&2;
  fi
}

function fail_pipeline_early() {
  local dont_interrupt_me_job_id
  dont_interrupt_me_job_id=$(scripts/api/get_job_id.rb --job-query "scope=success" --job-name "dont-interrupt-me")

  if [[ -n "${dont_interrupt_me_job_id}" ]]; then
    echoinfo "This pipeline cannot be interrupted due to \`dont-interrupt-me\` job ${dont_interrupt_me_job_id}"
  else
    echoinfo "Failing pipeline early for fast feedback due to test failures in rspec fail-fast."
    scripts/api/cancel_pipeline.rb
  fi
}

function danger_as_local() {
  # Force danger to skip CI source GitLab and fallback to "local only git repo".
  unset GITLAB_CI
  # We need to base SHA to help danger determine the base commit for this shallow clone.
  bundle exec danger dry_run --fail-on-errors=true --verbose --base="${CI_MERGE_REQUEST_DIFF_BASE_SHA}" --head="${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA:-$CI_COMMIT_SHA}"
}
