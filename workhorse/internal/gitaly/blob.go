package gitaly

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strconv"

	"gitlab.com/gitlab-org/gitaly/v15/proto/go/gitalypb"
	"gitlab.com/gitlab-org/gitaly/v15/streamio"
)

type BlobClient struct {
	gitalypb.BlobServiceClient
}

func (client *BlobClient) SendBlob(ctx context.Context, w http.ResponseWriter, request *gitalypb.GetBlobRequest) error {
	c, err := client.GetBlob(ctx, request)
	if err != nil {
		return fmt.Errorf("rpc failed: %v", err)
	}

	firstResponseReceived := false
	rr := streamio.NewReader(func() ([]byte, error) {
		resp, err := c.Recv()

		if !firstResponseReceived && err == nil {
			firstResponseReceived = true
			w.Header().Set("Content-Length", strconv.FormatInt(resp.GetSize(), 10))
		}

		return resp.GetData(), err
	})

	if _, err := io.Copy(w, rr); err != nil {
		return fmt.Errorf("copy rpc data: %v", err)
	}

	return nil
}
