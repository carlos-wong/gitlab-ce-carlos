# frozen_string_literal: true

module RackAttackSpecHelpers
  def post_args_with_token_headers(url, token_headers)
    [url, params: nil, headers: token_headers]
  end

  def api_get_args_with_token_headers(partial_url, token_headers)
    ["/api/#{API::API.version}#{partial_url}", params: nil, headers: token_headers]
  end

  def rss_url(user)
    "/dashboard/projects.atom?feed_token=#{user.feed_token}"
  end

  def private_token_headers(user)
    { 'HTTP_PRIVATE_TOKEN' => user.private_token }
  end

  def personal_access_token_headers(personal_access_token)
    { 'HTTP_PRIVATE_TOKEN' => personal_access_token.token }
  end

  def oauth_token_headers(oauth_access_token)
    { 'AUTHORIZATION' => "Bearer #{oauth_access_token.token}" }
  end

  def expect_rejection(&block)
    yield

    expect(response).to have_http_status(429)
  end
end
