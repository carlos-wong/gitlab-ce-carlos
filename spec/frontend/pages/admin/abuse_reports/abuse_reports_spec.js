import $ from 'jquery';
import '~/lib/utils/text_utility';
import AbuseReports from '~/pages/admin/abuse_reports/abuse_reports';
import { setTestTimeout } from 'helpers/timeout';

setTestTimeout(500);

describe('Abuse Reports', () => {
  const FIXTURE = 'abuse_reports/abuse_reports_list.html';
  const MAX_MESSAGE_LENGTH = 500;

  let $messages;

  const assertMaxLength = $message => {
    expect($message.text().length).toEqual(MAX_MESSAGE_LENGTH);
  };
  const findMessage = searchText =>
    $messages.filter((index, element) => element.innerText.indexOf(searchText) > -1).first();

  preloadFixtures(FIXTURE);

  beforeEach(() => {
    loadFixtures(FIXTURE);
    new AbuseReports(); // eslint-disable-line no-new
    $messages = $('.abuse-reports .message');
  });

  it('should truncate long messages', () => {
    const $longMessage = findMessage('LONG MESSAGE');

    expect($longMessage.data('originalMessage')).toEqual(expect.anything());
    assertMaxLength($longMessage);
  });

  it('should not truncate short messages', () => {
    const $shortMessage = findMessage('SHORT MESSAGE');

    expect($shortMessage.data('originalMessage')).not.toEqual(expect.anything());
  });

  it('should allow clicking a truncated message to expand and collapse the full message', () => {
    const $longMessage = findMessage('LONG MESSAGE');
    $longMessage.click();

    expect($longMessage.data('originalMessage').length).toEqual($longMessage.text().length);
    $longMessage.click();
    assertMaxLength($longMessage);
  });
});
