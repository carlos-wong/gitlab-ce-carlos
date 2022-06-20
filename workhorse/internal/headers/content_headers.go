package headers

import (
	"net/http"
	"regexp"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/utils/svg"
)

var (
	javaScriptTypeRegex = regexp.MustCompile(`^(text|application)\/javascript$`)

	imageTypeRegex   = regexp.MustCompile(`^image/*`)
	svgMimeTypeRegex = regexp.MustCompile(`^image/svg\+xml$`)

	textTypeRegex = regexp.MustCompile(`^text/*`)

	videoTypeRegex = regexp.MustCompile(`^video/*`)

	pdfTypeRegex = regexp.MustCompile(`application\/pdf`)

	attachmentRegex = regexp.MustCompile(`^attachment`)
	inlineRegex     = regexp.MustCompile(`^inline`)
)

// Mime types that can't be inlined. Usually subtypes of main types
var forbiddenInlineTypes = []*regexp.Regexp{svgMimeTypeRegex}

// Mime types that can be inlined. We can add global types like "image/" or
// specific types like "text/plain". If there is a specific type inside a global
// allowed type that can't be inlined we must add it to the forbiddenInlineTypes var.
// One example of this is the mime type "image". We allow all images to be
// inlined except for SVGs.
var allowedInlineTypes = []*regexp.Regexp{imageTypeRegex, textTypeRegex, videoTypeRegex, pdfTypeRegex}

const (
	svgContentType            = "image/svg+xml"
	textPlainContentType      = "text/plain; charset=utf-8"
	attachmentDispositionText = "attachment"
	inlineDispositionText     = "inline"
)

func SafeContentHeaders(data []byte, contentDisposition string) (string, string) {
	contentType := safeContentType(data)
	contentDisposition = safeContentDisposition(contentType, contentDisposition)
	return contentType, contentDisposition
}

func safeContentType(data []byte) string {
	// Special case for svg because DetectContentType detects it as text
	if svg.Is(data) {
		return svgContentType
	}

	// Override any existing Content-Type header from other ResponseWriters
	contentType := http.DetectContentType(data)

	// http.DetectContentType does not support JavaScript and would only
	// return text/plain. But for cautionary measures, just in case they start supporting
	// it down the road and start returning application/javascript, we want to handle it now
	// to avoid regressions.
	if isType(contentType, javaScriptTypeRegex) {
		return textPlainContentType
	}

	// If the content is text type, we set to plain, because we don't
	// want to render it inline if they're html or javascript
	if isType(contentType, textTypeRegex) {
		return textPlainContentType
	}

	return contentType
}

func safeContentDisposition(contentType string, contentDisposition string) string {
	// If the existing disposition is attachment we return that. This allow us
	// to force a download from GitLab (ie: RawController)
	if attachmentRegex.MatchString(contentDisposition) {
		return contentDisposition
	}

	// Checks for mime types that are forbidden to be inline
	for _, element := range forbiddenInlineTypes {
		if isType(contentType, element) {
			return attachmentDisposition(contentDisposition)
		}
	}

	// Checks for mime types allowed to be inline
	for _, element := range allowedInlineTypes {
		if isType(contentType, element) {
			return inlineDisposition(contentDisposition)
		}
	}

	// Anything else is set to attachment
	return attachmentDisposition(contentDisposition)
}

func attachmentDisposition(contentDisposition string) string {
	if contentDisposition == "" {
		return attachmentDispositionText
	}

	if inlineRegex.MatchString(contentDisposition) {
		return inlineRegex.ReplaceAllString(contentDisposition, attachmentDispositionText)
	}

	return contentDisposition
}

func inlineDisposition(contentDisposition string) string {
	if contentDisposition == "" {
		return inlineDispositionText
	}

	if attachmentRegex.MatchString(contentDisposition) {
		return attachmentRegex.ReplaceAllString(contentDisposition, inlineDispositionText)
	}

	return contentDisposition
}

func isType(contentType string, mimeType *regexp.Regexp) bool {
	return mimeType.MatchString(contentType)
}
