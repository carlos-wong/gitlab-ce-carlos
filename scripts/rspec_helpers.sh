#!/usr/bin/env bash

function retrieve_tests_metadata() {
  mkdir -p $(dirname "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}") $(dirname "${FLAKY_RSPEC_SUITE_REPORT_PATH}") "${RSPEC_PROFILING_FOLDER_PATH}"

  if [[ -n "${RETRIEVE_TESTS_METADATA_FROM_PAGES}" ]]; then
    if [[ ! -f "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}" ]]; then
      curl --location -o "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}" "https://gitlab-org.gitlab.io/gitlab/${KNAPSACK_RSPEC_SUITE_REPORT_PATH}" ||
        echo "{}" > "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}"
    fi

    if [[ ! -f "${FLAKY_RSPEC_SUITE_REPORT_PATH}" ]]; then
      curl --location -o "${FLAKY_RSPEC_SUITE_REPORT_PATH}" "https://gitlab-org.gitlab.io/gitlab/${FLAKY_RSPEC_SUITE_REPORT_PATH}" ||
        curl --location -o "${FLAKY_RSPEC_SUITE_REPORT_PATH}" "https://gitlab-org.gitlab.io/gitlab/rspec_flaky/report-suite.json" || # temporary back-compat
        echo "{}" > "${FLAKY_RSPEC_SUITE_REPORT_PATH}"
    fi
  else
    # ${CI_DEFAULT_BRANCH} might not be master in other forks but we want to
    # always target the canonical project here, so the branch must be hardcoded
    local project_path="gitlab-org/gitlab"
    local artifact_branch="master"
    local username="gitlab-bot"
    local job_name="update-tests-metadata"
    local test_metadata_job_id

    # Ruby
    test_metadata_job_id=$(scripts/api/get_job_id.rb --endpoint "https://gitlab.com/api/v4" --project "${project_path}" -q "status=success" -q "ref=${artifact_branch}" -q "username=${username}" -Q "scope=success" --job-name "${job_name}")

    if [[ -n "${test_metadata_job_id}" ]]; then
      echo "test_metadata_job_id: ${test_metadata_job_id}"

      if [[ ! -f "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}" ]]; then
        scripts/api/download_job_artifact.rb --endpoint "https://gitlab.com/api/v4" --project "${project_path}" --job-id "${test_metadata_job_id}" --artifact-path "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}" || echo "{}" > "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}"
      fi

      if [[ ! -f "${FLAKY_RSPEC_SUITE_REPORT_PATH}" ]]; then
        scripts/api/download_job_artifact.rb --endpoint "https://gitlab.com/api/v4" --project "${project_path}" --job-id "${test_metadata_job_id}" --artifact-path "${FLAKY_RSPEC_SUITE_REPORT_PATH}" ||
          scripts/api/download_job_artifact.rb --endpoint "https://gitlab.com/api/v4" --project "${project_path}" --job-id "${test_metadata_job_id}" --artifact-path "rspec_flaky/report-suite.json" || # temporary back-compat
          echo "{}" > "${FLAKY_RSPEC_SUITE_REPORT_PATH}"

        # temporary back-compat
        if [[ -f "rspec_flaky/report-suite.json" ]]; then
          mv "rspec_flaky/report-suite.json" "${FLAKY_RSPEC_SUITE_REPORT_PATH}"
        fi
      fi
    else
      echo "test_metadata_job_id couldn't be found!"
      echo "{}" > "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}"
      echo "{}" > "${FLAKY_RSPEC_SUITE_REPORT_PATH}"
    fi
  fi
}

function update_tests_metadata() {
  local rspec_flaky_folder_path="$(dirname "${FLAKY_RSPEC_SUITE_REPORT_PATH}")/"
  local knapsack_folder_path="$(dirname "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}")/"

  echo "{}" > "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}"

  scripts/merge-reports "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}" ${knapsack_folder_path}rspec*.json

  export FLAKY_RSPEC_GENERATE_REPORT="true"
  scripts/merge-reports "${FLAKY_RSPEC_SUITE_REPORT_PATH}" ${rspec_flaky_folder_path}all_*.json
  scripts/flaky_examples/prune-old-flaky-examples "${FLAKY_RSPEC_SUITE_REPORT_PATH}"

  if [[ "$CI_PIPELINE_SOURCE" == "schedule" ]]; then
    scripts/insert-rspec-profiling-data
  else
    echo "Not inserting profiling data as the pipeline is not a scheduled one."
  fi

  cleanup_individual_job_reports
}

function retrieve_tests_mapping() {
  mkdir -p $(dirname "$RSPEC_PACKED_TESTS_MAPPING_PATH")

  if [[ -n "${RETRIEVE_TESTS_METADATA_FROM_PAGES}" ]]; then
    if [[ ! -f "${RSPEC_PACKED_TESTS_MAPPING_PATH}" ]]; then
      (curl --location  -o "${RSPEC_PACKED_TESTS_MAPPING_PATH}.gz" "https://gitlab-org.gitlab.io/gitlab/${RSPEC_PACKED_TESTS_MAPPING_PATH}.gz" && gzip -d "${RSPEC_PACKED_TESTS_MAPPING_PATH}.gz") || echo "{}" > "${RSPEC_PACKED_TESTS_MAPPING_PATH}"
    fi
  else
    # ${CI_DEFAULT_BRANCH} might not be master in other forks but we want to
    # always target the canonical project here, so the branch must be hardcoded
    local project_path="gitlab-org/gitlab"
    local artifact_branch="master"
    local username="gitlab-bot"
    local job_name="update-tests-metadata"
    local test_metadata_with_mapping_job_id

    test_metadata_with_mapping_job_id=$(scripts/api/get_job_id.rb --endpoint "https://gitlab.com/api/v4" --project "${project_path}" -q "status=success" -q "ref=${artifact_branch}" -q "username=${username}" -Q "scope=success" --job-name "${job_name}")

    if [[ -n "${test_metadata_with_mapping_job_id}" ]]; then
      echo "test_metadata_with_mapping_job_id: ${test_metadata_with_mapping_job_id}"

      if [[ ! -f "${RSPEC_PACKED_TESTS_MAPPING_PATH}" ]]; then
        (scripts/api/download_job_artifact.rb --endpoint "https://gitlab.com/api/v4" --project "${project_path}" --job-id "${test_metadata_with_mapping_job_id}" --artifact-path "${RSPEC_PACKED_TESTS_MAPPING_PATH}.gz" && gzip -d "${RSPEC_PACKED_TESTS_MAPPING_PATH}.gz") || echo "{}" > "${RSPEC_PACKED_TESTS_MAPPING_PATH}"
      fi
    else
      echo "test_metadata_with_mapping_job_id couldn't be found!"
      echo "{}" > "${RSPEC_PACKED_TESTS_MAPPING_PATH}"
    fi
  fi

  scripts/unpack-test-mapping "${RSPEC_PACKED_TESTS_MAPPING_PATH}" "${RSPEC_TESTS_MAPPING_PATH}"
}

function retrieve_frontend_fixtures_mapping() {
  mkdir -p $(dirname "$FRONTEND_FIXTURES_MAPPING_PATH")

  if [[ -n "${RETRIEVE_TESTS_METADATA_FROM_PAGES}" ]]; then
    if [[ ! -f "${FRONTEND_FIXTURES_MAPPING_PATH}" ]]; then
      (curl --location  -o "${FRONTEND_FIXTURES_MAPPING_PATH}" "https://gitlab-org.gitlab.io/gitlab/${FRONTEND_FIXTURES_MAPPING_PATH}") || echo "{}" > "${FRONTEND_FIXTURES_MAPPING_PATH}"
    fi
  else
    # ${CI_DEFAULT_BRANCH} might not be master in other forks but we want to
    # always target the canonical project here, so the branch must be hardcoded
    local project_path="gitlab-org/gitlab"
    local artifact_branch="master"
    local username="gitlab-bot"
    local job_name="generate-frontend-fixtures-mapping"
    local test_metadata_with_mapping_job_id

    test_metadata_with_mapping_job_id=$(scripts/api/get_job_id.rb --endpoint "https://gitlab.com/api/v4" --project "${project_path}" -q "ref=${artifact_branch}" -q "username=${username}" -Q "scope=success" --job-name "${job_name}")

    if [[ $? -eq 0 ]] && [[ -n "${test_metadata_with_mapping_job_id}" ]]; then
      echo "test_metadata_with_mapping_job_id: ${test_metadata_with_mapping_job_id}"

      if [[ ! -f "${FRONTEND_FIXTURES_MAPPING_PATH}" ]]; then
        (scripts/api/download_job_artifact.rb --endpoint "https://gitlab.com/api/v4" --project "${project_path}" --job-id "${test_metadata_with_mapping_job_id}" --artifact-path "${FRONTEND_FIXTURES_MAPPING_PATH}") || echo "{}" > "${FRONTEND_FIXTURES_MAPPING_PATH}"
      fi
    else
      echo "test_metadata_with_mapping_job_id couldn't be found!"
      echo "{}" > "${FRONTEND_FIXTURES_MAPPING_PATH}"
    fi
  fi
}

function update_tests_mapping() {
  if ! crystalball_rspec_data_exists; then
    echo "No crystalball rspec data found."
    return 0
  fi

  scripts/generate-test-mapping "${RSPEC_TESTS_MAPPING_PATH}" crystalball/rspec*.yml
  scripts/pack-test-mapping "${RSPEC_TESTS_MAPPING_PATH}" "${RSPEC_PACKED_TESTS_MAPPING_PATH}"
  gzip "${RSPEC_PACKED_TESTS_MAPPING_PATH}"
  rm -f crystalball/rspec*.yml "${RSPEC_PACKED_TESTS_MAPPING_PATH}"
}

function crystalball_rspec_data_exists() {
  compgen -G "crystalball/rspec*.yml" >/dev/null
}

function retrieve_previous_failed_tests() {
  local directory_for_output_reports="${1}"
  local rspec_pg_regex="${2}"
  local rspec_ee_pg_regex="${3}"
  local pipeline_report_path="test_results/previous/test_reports.json"

  # Used to query merge requests. This variable reflects where the merge request has been created
  local target_project_path="${CI_MERGE_REQUEST_PROJECT_PATH}"
  local instance_url="${CI_SERVER_URL}"

  echo 'Attempting to build pipeline test report...'

  scripts/pipeline_test_report_builder.rb --instance-base-url "${instance_url}" --target-project "${target_project_path}" --mr-id "${CI_MERGE_REQUEST_IID}" --output-file-path "${pipeline_report_path}"

  echo 'Generating failed tests lists...'

  scripts/failed_tests.rb --previous-tests-report-path "${pipeline_report_path}" --output-directory "${directory_for_output_reports}" --rspec-pg-regex "${rspec_pg_regex}" --rspec-ee-pg-regex "${rspec_ee_pg_regex}"
}

function rspec_args() {
  local rspec_opts="${1}"
  local junit_report_file="${2:-${JUNIT_RESULT_FILE}}"

  echo "-Ispec -rspec_helper --color --format documentation --format RspecJunitFormatter --out ${junit_report_file} ${rspec_opts}"
}

function rspec_simple_job() {
  export NO_KNAPSACK="1"

  local rspec_cmd="bin/rspec $(rspec_args "${1}" "${2}")"
  echoinfo "Running RSpec command: ${rspec_cmd}"

  eval "${rspec_cmd}"
}

function rspec_db_library_code() {
  local db_files="spec/lib/gitlab/database/"

  rspec_simple_job "-- ${db_files}"
}

function debug_rspec_variables() {
  echoinfo "SKIP_FLAKY_TESTS_AUTOMATICALLY: ${SKIP_FLAKY_TESTS_AUTOMATICALLY}"
  echoinfo "RETRY_FAILED_TESTS_IN_NEW_PROCESS: ${RETRY_FAILED_TESTS_IN_NEW_PROCESS}"

  echoinfo "KNAPSACK_GENERATE_REPORT: ${KNAPSACK_GENERATE_REPORT}"
  echoinfo "FLAKY_RSPEC_GENERATE_REPORT: ${FLAKY_RSPEC_GENERATE_REPORT}"

  echoinfo "KNAPSACK_TEST_FILE_PATTERN: ${KNAPSACK_TEST_FILE_PATTERN}"
  echoinfo "KNAPSACK_LOG_LEVEL: ${KNAPSACK_LOG_LEVEL}"
  echoinfo "KNAPSACK_REPORT_PATH: ${KNAPSACK_REPORT_PATH}"

  echoinfo "FLAKY_RSPEC_SUITE_REPORT_PATH: ${FLAKY_RSPEC_SUITE_REPORT_PATH}"
  echoinfo "FLAKY_RSPEC_REPORT_PATH: ${FLAKY_RSPEC_REPORT_PATH}"
  echoinfo "NEW_FLAKY_RSPEC_REPORT_PATH: ${NEW_FLAKY_RSPEC_REPORT_PATH}"
  echoinfo "SKIPPED_FLAKY_TESTS_REPORT_PATH: ${SKIPPED_FLAKY_TESTS_REPORT_PATH}"
  echoinfo "RETRIED_TESTS_REPORT_PATH: ${RETRIED_TESTS_REPORT_PATH}"

  echoinfo "CRYSTALBALL: ${CRYSTALBALL}"
}

function rspec_paralellized_job() {
  read -ra job_name <<< "${CI_JOB_NAME}"
  local test_tool="${job_name[0]}"
  local test_level="${job_name[1]}"
  local report_name=$(echo "${CI_JOB_NAME}" | sed -E 's|[/ ]|_|g') # e.g. 'rspec unit pg12 1/24' would become 'rspec_unit_pg12_1_24'
  local rspec_opts="${1}"
  local spec_folder_prefixes=""
  local rspec_flaky_folder_path="$(dirname "${FLAKY_RSPEC_SUITE_REPORT_PATH}")/"
  local knapsack_folder_path="$(dirname "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}")/"
  local rspec_run_status=0

  if [[ "${test_tool}" =~ "-ee" ]]; then
    spec_folder_prefixes="'ee/'"
  fi

  if [[ "${test_tool}" =~ "-jh" ]]; then
    spec_folder_prefixes="'jh/'"
  fi

  if [[ "${test_tool}" =~ "-all" ]]; then
    spec_folder_prefixes="['', 'ee/', 'jh/']"
  fi

  export KNAPSACK_LOG_LEVEL="debug"
  export KNAPSACK_REPORT_PATH="${knapsack_folder_path}${report_name}_report.json"

  # There's a bug where artifacts are sometimes not downloaded. Since specs can run without the Knapsack report, we can
  # handle the missing artifact gracefully here. See https://gitlab.com/gitlab-org/gitlab/-/issues/212349.
  if [[ ! -f "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}" ]]; then
    echo "{}" > "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}"
  fi

  cp "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}" "${KNAPSACK_REPORT_PATH}"

  export KNAPSACK_TEST_FILE_PATTERN=$(ruby -r./tooling/quality/test_level.rb -e "puts Quality::TestLevel.new(${spec_folder_prefixes}).pattern(:${test_level})")
  export FLAKY_RSPEC_REPORT_PATH="${rspec_flaky_folder_path}all_${report_name}_report.json"
  export NEW_FLAKY_RSPEC_REPORT_PATH="${rspec_flaky_folder_path}new_${report_name}_report.json"
  export SKIPPED_FLAKY_TESTS_REPORT_PATH="${rspec_flaky_folder_path}skipped_flaky_tests_${report_name}_report.txt"
  export RETRIED_TESTS_REPORT_PATH="${rspec_flaky_folder_path}retried_tests_${report_name}_report.txt"

  if [[ -d "ee/" ]]; then
    export KNAPSACK_GENERATE_REPORT="true"
    export FLAKY_RSPEC_GENERATE_REPORT="true"

    if [[ ! -f $FLAKY_RSPEC_REPORT_PATH ]]; then
      echo "{}" > "${FLAKY_RSPEC_REPORT_PATH}"
    fi

    if [[ ! -f $NEW_FLAKY_RSPEC_REPORT_PATH ]]; then
      echo "{}" > "${NEW_FLAKY_RSPEC_REPORT_PATH}"
    fi
  fi

  debug_rspec_variables

  if [[ -n $RSPEC_TESTS_MAPPING_ENABLED ]]; then
    tooling/bin/parallel_rspec --rspec_args "$(rspec_args "${rspec_opts}")" --filter "tmp/matching_tests.txt" || rspec_run_status=$?
  else
    tooling/bin/parallel_rspec --rspec_args "$(rspec_args "${rspec_opts}")" || rspec_run_status=$?
  fi

  echoinfo "RSpec exited with ${rspec_run_status}."

  # Experiment to retry failed examples in a new RSpec process: https://gitlab.com/gitlab-org/quality/team-tasks/-/issues/1148
  if [[ $rspec_run_status -ne 0 ]]; then
    if [[ "${RETRY_FAILED_TESTS_IN_NEW_PROCESS}" == "true" ]]; then
      retry_failed_rspec_examples
      rspec_run_status=$?
    fi
  else
    echosuccess "No examples to retry, congrats!"
  fi

  exit $rspec_run_status
}

function retry_failed_rspec_examples() {
  local rspec_run_status=0

  # Keep track of the tests that are retried, later consolidated in a single file by the `rspec:flaky-tests-report` job
  local failed_examples=$(grep " failed" ${RSPEC_LAST_RUN_RESULTS_FILE})
  echo "${CI_JOB_URL}" > "${RETRIED_TESTS_REPORT_PATH}"
  echo $failed_examples >> "${RETRIED_TESTS_REPORT_PATH}"

  echoinfo "Retrying the failing examples in a new RSpec process..."

  install_junit_merge_gem

  # Disable Crystalball on retry to not overwrite the existing report
  export CRYSTALBALL="false"

  # Disable simplecov so retried tests don't override test coverage report
  export SIMPLECOV=0

  # Retry only the tests that failed on first try
  rspec_simple_job "--only-failures --pattern \"${KNAPSACK_TEST_FILE_PATTERN}\"" "${JUNIT_RETRY_FILE}"
  rspec_run_status=$?

  # Merge the JUnit report from retry into the first-try report
  junit_merge "${JUNIT_RETRY_FILE}" "${JUNIT_RESULT_FILE}" --update-only

  exit $rspec_run_status
}

function rspec_rerun_previous_failed_tests() {
  local test_file_count_threshold=${RSPEC_PREVIOUS_FAILED_TEST_FILE_COUNT_THRESHOLD:-10}
  local matching_tests_file=${1}
  local rspec_opts=${2}
  local test_files="$(cat "${matching_tests_file}")"
  local test_file_count=$(wc -w "${matching_tests_file}" | awk {'print $1'})

  if [[ "${test_file_count}" -gt "${test_file_count_threshold}" ]]; then
    echo "This job is intentionally exited because there are more than ${test_file_count_threshold} test files to rerun."
    exit 0
  fi

  if [[ -n $test_files ]]; then
    rspec_simple_job "${test_files}"
  else
    echo "No failed test files to rerun"
  fi
}

function rspec_fail_fast() {
  local test_file_count_threshold=${RSPEC_FAIL_FAST_TEST_FILE_COUNT_THRESHOLD:-10}
  local matching_tests_file=${1}
  local rspec_opts=${2}
  local test_files="$(cat "${matching_tests_file}")"
  local test_file_count=$(wc -w "${matching_tests_file}" | awk {'print $1'})

  if [[ "${test_file_count}" -gt "${test_file_count_threshold}" ]]; then
    echo "This job is intentionally skipped because there are more than ${test_file_count_threshold} test files matched,"
    echo "which would take too long to run in this job."
    echo "All the tests would be run in other rspec jobs."
    exit 0
  fi

  if [[ -n $test_files ]]; then
    rspec_simple_job "${rspec_opts} ${test_files}"
  else
    echo "No rspec fail-fast tests to run"
  fi
}

function rspec_matched_foss_tests() {
  local test_file_count_threshold=20
  local matching_tests_file=${1}
  local rspec_opts=${2}
  local test_files="$(cat "${matching_tests_file}")"
  local test_file_count=$(wc -w "${matching_tests_file}" | awk {'print $1'})

  if [[ "${test_file_count}" -gt "${test_file_count_threshold}" ]]; then
    echo "This job is intentionally failed because there are more than ${test_file_count_threshold} FOSS test files matched,"
    echo "which would take too long to run in this job."
    echo "To reduce the likelihood of breaking FOSS pipelines,"
    echo "please add ~\"pipeline:run-as-if-foss\" label to the merge request and trigger a new pipeline."
    echo "This would run all as-if-foss jobs in this merge request"
    echo "and remove this failing job from the pipeline."
    exit 1
  fi

  if [[ -n $test_files ]]; then
    rspec_simple_job "${rspec_opts} ${test_files}"
  else
    echo "No impacted FOSS rspec tests to run"
  fi
}

function generate_frontend_fixtures_mapping() {
  local pattern=""

  if [[ -d "ee/" ]]; then
    pattern=",ee/"
  fi

  if [[ -d "jh/" ]]; then
    pattern="${pattern},jh/"
  fi

  if [[ -n "${pattern}" ]]; then
    pattern="{${pattern}}"
  fi

  pattern="${pattern}spec/frontend/fixtures/**/*.rb"

  export GENERATE_FRONTEND_FIXTURES_MAPPING="true"

  mkdir -p $(dirname "$FRONTEND_FIXTURES_MAPPING_PATH")

  rspec_simple_job "--pattern \"${pattern}\""
}

function cleanup_individual_job_reports() {
  local rspec_flaky_folder_path="$(dirname "${FLAKY_RSPEC_SUITE_REPORT_PATH}")/"
  local knapsack_folder_path="$(dirname "${KNAPSACK_RSPEC_SUITE_REPORT_PATH}")/"

  rm -rf ${knapsack_folder_path}rspec*.json \
    ${rspec_flaky_folder_path}all_*.json \
    ${rspec_flaky_folder_path}new_*.json \
    ${rspec_flaky_folder_path}skipped_flaky_tests_*_report.txt \
    ${rspec_flaky_folder_path}retried_tests_*_report.txt \
    ${RSPEC_LAST_RUN_RESULTS_FILE} \
    ${RSPEC_PROFILING_FOLDER_PATH}/**/*
  rmdir ${RSPEC_PROFILING_FOLDER_PATH} || true
}

function generate_flaky_tests_reports() {
  local rspec_flaky_folder_path="$(dirname "${FLAKY_RSPEC_SUITE_REPORT_PATH}")/"

  debug_rspec_variables

  mkdir -p ${rspec_flaky_folder_path}

  find ${rspec_flaky_folder_path} -type f -name 'skipped_flaky_tests_*_report.txt' -exec cat {} + >> "${SKIPPED_FLAKY_TESTS_REPORT_PATH}"
  find ${rspec_flaky_folder_path} -type f -name 'retried_tests_*_report.txt' -exec cat {} + >> "${RETRIED_TESTS_REPORT_PATH}"

  cleanup_individual_job_reports
}
