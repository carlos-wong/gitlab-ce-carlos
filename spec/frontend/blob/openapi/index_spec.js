import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import renderOpenApi from '~/blob/openapi';

describe('OpenAPI blob viewer', () => {
  const id = 'js-openapi-viewer';
  const mockEndpoint = 'some/endpoint';
  let mock;

  beforeEach(async () => {
    setHTMLFixture(`<div id="${id}" data-endpoint="${mockEndpoint}"></div>`);
    mock = new MockAdapter(axios).onGet().reply(200);
    await renderOpenApi();
  });

  afterEach(() => {
    resetHTMLFixture();
    mock.restore();
  });

  it('initializes SwaggerUI with the correct configuration', () => {
    expect(document.body.innerHTML).toContain(
      '<iframe src="/-/sandbox/swagger" sandbox="allow-scripts" frameborder="0" width="100%" height="1000"></iframe>',
    );
  });
});
