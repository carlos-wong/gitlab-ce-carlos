package upstream

import (
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/require"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/config"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/helper"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/testhelper"
)

const (
	geoProxyEndpoint = "/api/v4/geo/proxy"
	testDocumentRoot = "testdata/public"
)

type testCase struct {
	desc             string
	path             string
	expectedResponse string
}

func TestMain(m *testing.M) {
	// Secret should be configured before any Geo API poll happens to prevent
	// race conditions where the first API call happens without a secret path
	testhelper.ConfigureSecret()

	os.Exit(m.Run())
}

func TestRouting(t *testing.T) {
	handle := func(u *upstream, regex string) routeEntry {
		handler := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			io.WriteString(w, regex)
		})
		return u.route("", regex, handler)
	}

	const (
		foobar = `\A/foobar\z`
		quxbaz = `\A/quxbaz\z`
		main   = ""
	)

	u := newUpstream(config.Config{}, logrus.StandardLogger(), func(u *upstream) {
		u.Routes = []routeEntry{
			handle(u, foobar),
			handle(u, quxbaz),
			handle(u, main),
		}
	})
	ts := httptest.NewServer(u)
	defer ts.Close()

	testCases := []testCase{
		{"main route works", "/", main},
		{"foobar route works", "/foobar", foobar},
		{"quxbaz route works", "/quxbaz", quxbaz},
		{"path traversal works, ends up in quxbaz", "/foobar/../quxbaz", quxbaz},
		{"escaped path traversal does not match any route", "/foobar%2f%2e%2e%2fquxbaz", main},
		{"double escaped path traversal does not match any route", "/foobar%252f%252e%252e%252fquxbaz", main},
	}

	runTestCases(t, ts, testCases)
}

// This test can be removed when the environment variable `GEO_SECONDARY_PROXY` is removed
func TestGeoProxyFeatureDisabledOnGeoSecondarySite(t *testing.T) {
	// We could just not set up the primary, but then we'd have to assert
	// that the internal API call isn't made. This is easier.
	remoteServer, rsDeferredClose := startRemoteServer("Geo primary")
	defer rsDeferredClose()

	geoProxyEndpointResponseBody := fmt.Sprintf(`{"geo_proxy_url":"%v"}`, remoteServer.URL)
	railsServer, deferredClose := startRailsServer("Local Rails server", &geoProxyEndpointResponseBody)
	defer deferredClose()

	ws, wsDeferredClose, _ := startWorkhorseServer(railsServer.URL, false)
	defer wsDeferredClose()

	testCases := []testCase{
		{"jobs request is served locally", "/api/v4/jobs/request", "Local Rails server received request to path /api/v4/jobs/request"},
		{"health check is served locally", "/-/health", "Local Rails server received request to path /-/health"},
		{"unknown route is served locally", "/anything", "Local Rails server received request to path /anything"},
	}

	runTestCases(t, ws, testCases)
}

func TestGeoProxyFeatureEnabledOnGeoSecondarySite(t *testing.T) {
	testCases := []testCase{
		{"push from secondary is forwarded", "/-/push_from_secondary/foo/bar.git/info/refs", "Geo primary received request to path /-/push_from_secondary/foo/bar.git/info/refs"},
		{"LFS files are served locally", "/group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6", "Local Rails server received request to path /group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6"},
		{"jobs request is forwarded", "/api/v4/jobs/request", "Geo primary received request to path /api/v4/jobs/request"},
		{"health check is served locally", "/-/health", "Local Rails server received request to path /-/health"},
		{"unknown route is forwarded", "/anything", "Geo primary received request to path /anything"},
	}

	runTestCasesWithGeoProxyEnabled(t, testCases)
}

// This test can be removed when the environment variable `GEO_SECONDARY_PROXY` is removed
func TestGeoProxyFeatureDisabledOnNonGeoSecondarySite(t *testing.T) {
	geoProxyEndpointResponseBody := "{}"
	railsServer, deferredClose := startRailsServer("Local Rails server", &geoProxyEndpointResponseBody)
	defer deferredClose()

	ws, wsDeferredClose, _ := startWorkhorseServer(railsServer.URL, false)
	defer wsDeferredClose()

	testCases := []testCase{
		{"LFS files are served locally", "/group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6", "Local Rails server received request to path /group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6"},
		{"jobs request is served locally", "/api/v4/jobs/request", "Local Rails server received request to path /api/v4/jobs/request"},
		{"health check is served locally", "/-/health", "Local Rails server received request to path /-/health"},
		{"unknown route is served locally", "/anything", "Local Rails server received request to path /anything"},
	}

	runTestCases(t, ws, testCases)
}

func TestGeoProxyFeatureEnabledOnNonGeoSecondarySite(t *testing.T) {
	geoProxyEndpointResponseBody := "{}"
	railsServer, deferredClose := startRailsServer("Local Rails server", &geoProxyEndpointResponseBody)
	defer deferredClose()

	ws, wsDeferredClose, _ := startWorkhorseServer(railsServer.URL, true)
	defer wsDeferredClose()

	testCases := []testCase{
		{"LFS files are served locally", "/group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6", "Local Rails server received request to path /group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6"},
		{"jobs request is served locally", "/api/v4/jobs/request", "Local Rails server received request to path /api/v4/jobs/request"},
		{"health check is served locally", "/-/health", "Local Rails server received request to path /-/health"},
		{"unknown route is served locally", "/anything", "Local Rails server received request to path /anything"},
	}

	runTestCases(t, ws, testCases)
}

func TestGeoProxyFeatureEnabledButWithAPIError(t *testing.T) {
	geoProxyEndpointResponseBody := "Invalid response"
	railsServer, deferredClose := startRailsServer("Local Rails server", &geoProxyEndpointResponseBody)
	defer deferredClose()

	ws, wsDeferredClose, _ := startWorkhorseServer(railsServer.URL, true)
	defer wsDeferredClose()

	testCases := []testCase{
		{"LFS files are served locally", "/group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6", "Local Rails server received request to path /group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6"},
		{"jobs request is served locally", "/api/v4/jobs/request", "Local Rails server received request to path /api/v4/jobs/request"},
		{"health check is served locally", "/-/health", "Local Rails server received request to path /-/health"},
		{"unknown route is served locally", "/anything", "Local Rails server received request to path /anything"},
	}

	runTestCases(t, ws, testCases)
}

func TestGeoProxyFeatureEnablingAndDisabling(t *testing.T) {
	remoteServer, rsDeferredClose := startRemoteServer("Geo primary")
	defer rsDeferredClose()

	geoProxyEndpointEnabledResponseBody := fmt.Sprintf(`{"geo_proxy_url":"%v"}`, remoteServer.URL)
	geoProxyEndpointDisabledResponseBody := "{}"
	geoProxyEndpointResponseBody := geoProxyEndpointEnabledResponseBody

	railsServer, deferredClose := startRailsServer("Local Rails server", &geoProxyEndpointResponseBody)
	defer deferredClose()

	ws, wsDeferredClose, waitForNextApiPoll := startWorkhorseServer(railsServer.URL, true)
	defer wsDeferredClose()

	testCasesLocal := []testCase{
		{"LFS files are served locally", "/group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6", "Local Rails server received request to path /group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6"},
		{"jobs request is served locally", "/api/v4/jobs/request", "Local Rails server received request to path /api/v4/jobs/request"},
		{"health check is served locally", "/-/health", "Local Rails server received request to path /-/health"},
		{"unknown route is served locally", "/anything", "Local Rails server received request to path /anything"},
	}

	testCasesProxied := []testCase{
		{"push from secondary is forwarded", "/-/push_from_secondary/foo/bar.git/info/refs", "Geo primary received request to path /-/push_from_secondary/foo/bar.git/info/refs"},
		{"LFS files are served locally", "/group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6", "Local Rails server received request to path /group/project.git/gitlab-lfs/objects/37446575700829a11278ad3a550f244f45d5ae4fe1552778fa4f041f9eaeecf6"},
		{"jobs request is forwarded", "/api/v4/jobs/request", "Geo primary received request to path /api/v4/jobs/request"},
		{"health check is served locally", "/-/health", "Local Rails server received request to path /-/health"},
		{"unknown route is forwarded", "/anything", "Geo primary received request to path /anything"},
	}

	// Enabled initially, run tests
	runTestCases(t, ws, testCasesProxied)

	// Disable proxying and run tests. It's safe to write to
	// geoProxyEndpointResponseBody because the polling goroutine is blocked.
	geoProxyEndpointResponseBody = geoProxyEndpointDisabledResponseBody
	waitForNextApiPoll()

	runTestCases(t, ws, testCasesLocal)

	// Re-enable proxying and run tests
	geoProxyEndpointResponseBody = geoProxyEndpointEnabledResponseBody
	waitForNextApiPoll()

	runTestCases(t, ws, testCasesProxied)
}

func TestGeoProxyUpdatesExtraDataWhenChanged(t *testing.T) {
	var expectedGeoProxyExtraData string

	remoteServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "1", r.Header.Get("Gitlab-Workhorse-Geo-Proxy"), "custom proxy header")
		require.Equal(t, expectedGeoProxyExtraData, r.Header.Get("Gitlab-Workhorse-Geo-Proxy-Extra-Data"), "custom extra data header")
		w.WriteHeader(http.StatusOK)
	}))
	defer remoteServer.Close()

	geoProxyEndpointExtraData1 := fmt.Sprintf(`{"geo_proxy_url":"%v","geo_proxy_extra_data":"data1"}`, remoteServer.URL)
	geoProxyEndpointExtraData2 := fmt.Sprintf(`{"geo_proxy_url":"%v","geo_proxy_extra_data":"data2"}`, remoteServer.URL)
	geoProxyEndpointExtraData3 := fmt.Sprintf(`{"geo_proxy_url":"%v"}`, remoteServer.URL)
	geoProxyEndpointResponseBody := geoProxyEndpointExtraData1
	expectedGeoProxyExtraData = "data1"

	railsServer, deferredClose := startRailsServer("Local Rails server", &geoProxyEndpointResponseBody)
	defer deferredClose()

	ws, wsDeferredClose, waitForNextApiPoll := startWorkhorseServer(railsServer.URL, true)
	defer wsDeferredClose()

	http.Get(ws.URL)

	// Verify that the expected header changes after next updated poll.
	geoProxyEndpointResponseBody = geoProxyEndpointExtraData2
	expectedGeoProxyExtraData = "data2"
	waitForNextApiPoll()

	http.Get(ws.URL)

	// Validate that non-existing extra data results in empty header
	geoProxyEndpointResponseBody = geoProxyEndpointExtraData3
	expectedGeoProxyExtraData = ""
	waitForNextApiPoll()

	http.Get(ws.URL)
}

func TestGeoProxySetsCustomHeader(t *testing.T) {
	testCases := []struct {
		desc      string
		json      string
		extraData string
	}{
		{"no extra data", `{"geo_proxy_url":"%v"}`, ""},
		{"with extra data", `{"geo_proxy_url":"%v","geo_proxy_extra_data":"extra-geo-data"}`, "extra-geo-data"},
	}

	for _, tc := range testCases {
		t.Run(tc.desc, func(t *testing.T) {
			remoteServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				require.Equal(t, "1", r.Header.Get("Gitlab-Workhorse-Geo-Proxy"), "custom proxy header")
				require.Equal(t, tc.extraData, r.Header.Get("Gitlab-Workhorse-Geo-Proxy-Extra-Data"), "custom proxy extra data header")
				w.WriteHeader(http.StatusOK)
			}))
			defer remoteServer.Close()

			geoProxyEndpointResponseBody := fmt.Sprintf(tc.json, remoteServer.URL)
			railsServer, deferredClose := startRailsServer("Local Rails server", &geoProxyEndpointResponseBody)
			defer deferredClose()

			ws, wsDeferredClose, _ := startWorkhorseServer(railsServer.URL, true)
			defer wsDeferredClose()

			http.Get(ws.URL)
		})
	}
}

func runTestCases(t *testing.T, ws *httptest.Server, testCases []testCase) {
	t.Helper()
	for _, tc := range testCases {
		t.Run(tc.desc, func(t *testing.T) {
			resp, err := http.Get(ws.URL + tc.path)
			require.NoError(t, err)
			defer resp.Body.Close()

			body, err := ioutil.ReadAll(resp.Body)
			require.NoError(t, err)

			require.Equal(t, 200, resp.StatusCode, "response code")
			require.Equal(t, tc.expectedResponse, string(body))
		})
	}
}

func runTestCasesWithGeoProxyEnabled(t *testing.T, testCases []testCase) {
	remoteServer, rsDeferredClose := startRemoteServer("Geo primary")
	defer rsDeferredClose()

	geoProxyEndpointResponseBody := fmt.Sprintf(`{"geo_proxy_url":"%v"}`, remoteServer.URL)
	railsServer, deferredClose := startRailsServer("Local Rails server", &geoProxyEndpointResponseBody)
	defer deferredClose()

	ws, wsDeferredClose, _ := startWorkhorseServer(railsServer.URL, true)
	defer wsDeferredClose()

	runTestCases(t, ws, testCases)
}

func newUpstreamConfig(authBackend string) *config.Config {
	return &config.Config{
		Version:            "123",
		DocumentRoot:       testDocumentRoot,
		Backend:            helper.URLMustParse(authBackend),
		ImageResizerConfig: config.DefaultImageResizerConfig,
	}
}

func startRemoteServer(serverName string) (*httptest.Server, func()) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body := serverName + " received request to path " + r.URL.Path

		w.WriteHeader(200)
		fmt.Fprint(w, body)
	}))

	return ts, ts.Close
}

func startRailsServer(railsServerName string, geoProxyEndpointResponseBody *string) (*httptest.Server, func()) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body string

		if r.URL.Path == geoProxyEndpoint {
			w.Header().Set("Content-Type", "application/vnd.gitlab-workhorse+json")
			body = *geoProxyEndpointResponseBody
		} else {
			body = railsServerName + " received request to path " + r.URL.Path
		}

		w.WriteHeader(200)
		fmt.Fprint(w, body)
	}))

	return ts, ts.Close
}

func startWorkhorseServer(railsServerURL string, enableGeoProxyFeature bool) (*httptest.Server, func(), func()) {
	geoProxySleepC := make(chan struct{})
	geoProxySleep := func(time.Duration) {
		geoProxySleepC <- struct{}{}
		<-geoProxySleepC
	}

	myConfigureRoutes := func(u *upstream) {
		// Enable environment variable "feature flag"
		u.enableGeoProxyFeature = enableGeoProxyFeature

		// Replace the time.Sleep function with geoProxySleep
		u.geoProxyPollSleep = geoProxySleep

		// call original
		configureRoutes(u)
	}
	cfg := newUpstreamConfig(railsServerURL)
	upstreamHandler := newUpstream(*cfg, logrus.StandardLogger(), myConfigureRoutes)
	ws := httptest.NewServer(upstreamHandler)

	waitForNextApiPoll := func() {}

	if enableGeoProxyFeature {
		// Wait for geoProxySleep to be entered for the first time
		<-geoProxySleepC

		waitForNextApiPoll = func() {
			// Cause geoProxySleep to return
			geoProxySleepC <- struct{}{}

			// Wait for geoProxySleep to be entered again
			<-geoProxySleepC
		}
	}

	return ws, ws.Close, waitForNextApiPoll
}
