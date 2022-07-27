export default () => ({
  jobEndpoint: null,
  jobLogEndpoint: null,

  // sidebar
  isSidebarOpen: true,

  isLoading: false,
  hasError: false,
  job: {},

  // scroll buttons state
  isScrollBottomDisabled: true,
  isScrollTopDisabled: true,

  // Used to check if we should keep the automatic scroll
  isScrolledToBottomBeforeReceivingJobLog: true,

  jobLog: [],
  isJobLogComplete: false,
  jobLogSize: 0,
  isJobLogSizeVisible: false,
  jobLogTimeout: 0,

  // used as a query parameter to fetch the job log
  jobLogState: null,

  // sidebar dropdown & list of jobs
  isLoadingJobs: false,
  selectedStage: '',
  stages: [],
  jobs: [],
});
