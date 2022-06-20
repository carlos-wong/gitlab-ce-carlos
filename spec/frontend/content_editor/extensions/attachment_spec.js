import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import Attachment from '~/content_editor/extensions/attachment';
import Image from '~/content_editor/extensions/image';
import Audio from '~/content_editor/extensions/audio';
import Video from '~/content_editor/extensions/video';
import Link from '~/content_editor/extensions/link';
import Loading from '~/content_editor/extensions/loading';
import { VARIANT_DANGER } from '~/flash';
import httpStatus from '~/lib/utils/http_status';
import eventHubFactory from '~/helpers/event_hub_factory';
import { createTestEditor, createDocBuilder } from '../test_utils';

const PROJECT_WIKI_ATTACHMENT_IMAGE_HTML = `<p data-sourcepos="1:1-1:27" dir="auto">
  <a class="no-attachment-icon" href="/group1/project1/-/wikis/test-file.png" target="_blank" rel="noopener noreferrer" data-canonical-src="test-file.png">
    <img alt="test-file" class="lazy" data-src="/group1/project1/-/wikis/test-file.png" data-canonical-src="test-file.png">
  </a>
</p>`;

const PROJECT_WIKI_ATTACHMENT_VIDEO_HTML = `<p data-sourcepos="1:1-1:132" dir="auto">
  <span class="media-container video-container">
    <video src="/group1/project1/-/wikis/test-file.mp4" controls="true" data-setup="{}" data-title="test-file" width="400" preload="metadata" data-canonical-src="test-file.mp4">
    </video>
    <a href="/himkp/test/-/wikis/test-file.mp4" target="_blank" rel="noopener noreferrer" title="Download 'test-file'" data-canonical-src="test-file.mp4">test-file</a>
  </span>
</p>`;

const PROJECT_WIKI_ATTACHMENT_AUDIO_HTML = `<p data-sourcepos="3:1-3:74" dir="auto">
  <span class="media-container audio-container">
    <audio src="/himkp/test/-/wikis/test-file.mp3" controls="true" data-setup="{}" data-title="test-file" data-canonical-src="test-file.mp3">
    </audio>
    <a href="/himkp/test/-/wikis/test-file.mp3" target="_blank" rel="noopener noreferrer" title="Download 'test-file'" data-canonical-src="test-file.mp3">test-file</a>
  </span>
</p>`;

const PROJECT_WIKI_ATTACHMENT_LINK_HTML = `<p data-sourcepos="1:1-1:26" dir="auto">
  <a href="/group1/project1/-/wikis/test-file.zip" data-canonical-src="test-file.zip">test-file</a>
</p>`;

describe('content_editor/extensions/attachment', () => {
  let tiptapEditor;
  let doc;
  let p;
  let image;
  let audio;
  let video;
  let loading;
  let link;
  let renderMarkdown;
  let mock;
  let eventHub;

  const uploadsPath = '/uploads/';
  const imageFile = new File(['foo'], 'test-file.png', { type: 'image/png' });
  const audioFile = new File(['foo'], 'test-file.mp3', { type: 'audio/mpeg' });
  const videoFile = new File(['foo'], 'test-file.mp4', { type: 'video/mp4' });
  const attachmentFile = new File(['foo'], 'test-file.zip', { type: 'application/zip' });

  const expectDocumentAfterTransaction = ({ number, expectedDoc, action }) => {
    return new Promise((resolve) => {
      let counter = 1;
      const handleTransaction = async () => {
        if (counter === number) {
          expect(tiptapEditor.state.doc.toJSON()).toEqual(expectedDoc.toJSON());
          tiptapEditor.off('update', handleTransaction);
          await waitForPromises();
          resolve();
        }

        counter += 1;
      };

      tiptapEditor.on('update', handleTransaction);
      action();
    });
  };

  beforeEach(() => {
    renderMarkdown = jest.fn();
    eventHub = eventHubFactory();

    tiptapEditor = createTestEditor({
      extensions: [
        Loading,
        Link,
        Image,
        Audio,
        Video,
        Attachment.configure({ renderMarkdown, uploadsPath, eventHub }),
      ],
    });

    ({
      builders: { doc, p, image, audio, video, loading, link },
    } = createDocBuilder({
      tiptapEditor,
      names: {
        loading: { markType: Loading.name },
        image: { nodeType: Image.name },
        link: { nodeType: Link.name },
        audio: { nodeType: Audio.name },
        video: { nodeType: Video.name },
      },
    }));

    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.reset();
  });

  it.each`
    eventType  | propName         | eventData                                                             | output
    ${'paste'} | ${'handlePaste'} | ${{ clipboardData: { getData: jest.fn(), files: [attachmentFile] } }} | ${true}
    ${'paste'} | ${'handlePaste'} | ${{ clipboardData: { getData: jest.fn(), files: [] } }}               | ${undefined}
    ${'drop'}  | ${'handleDrop'}  | ${{ dataTransfer: { getData: jest.fn(), files: [attachmentFile] } }}  | ${true}
  `('handles $eventType properly', ({ eventType, propName, eventData, output }) => {
    const event = Object.assign(new Event(eventType), eventData);
    const handled = tiptapEditor.view.someProp(propName, (eventHandler) => {
      return eventHandler(tiptapEditor.view, event);
    });

    expect(handled).toBe(output);
  });

  describe('uploadAttachment command', () => {
    let initialDoc;
    beforeEach(() => {
      initialDoc = doc(p(''));
      tiptapEditor.commands.setContent(initialDoc.toJSON());
    });

    describe.each`
      nodeType   | mimeType        | html                                  | file         | mediaType
      ${'image'} | ${'image/png'}  | ${PROJECT_WIKI_ATTACHMENT_IMAGE_HTML} | ${imageFile} | ${(attrs) => image(attrs)}
      ${'audio'} | ${'audio/mpeg'} | ${PROJECT_WIKI_ATTACHMENT_AUDIO_HTML} | ${audioFile} | ${(attrs) => audio(attrs)}
      ${'video'} | ${'video/mp4'}  | ${PROJECT_WIKI_ATTACHMENT_VIDEO_HTML} | ${videoFile} | ${(attrs) => video(attrs)}
    `('when the file has $nodeType mime type', ({ mimeType, html, file, mediaType }) => {
      const base64EncodedFile = `data:${mimeType};base64,Zm9v`;

      beforeEach(() => {
        renderMarkdown.mockResolvedValue(html);
      });

      describe('when uploading succeeds', () => {
        const successResponse = {
          link: {
            markdown: `![test-file](${file.name})`,
          },
        };

        beforeEach(() => {
          mock.onPost().reply(httpStatus.OK, successResponse);
        });

        it('inserts a media content with src set to the encoded content and uploading true', async () => {
          const expectedDoc = doc(p(mediaType({ uploading: true, src: base64EncodedFile })));

          await expectDocumentAfterTransaction({
            number: 1,
            expectedDoc,
            action: () => tiptapEditor.commands.uploadAttachment({ file }),
          });
        });

        it('updates the inserted content with canonicalSrc when upload is successful', async () => {
          const expectedDoc = doc(
            p(
              mediaType({
                canonicalSrc: file.name,
                src: base64EncodedFile,
                alt: 'test-file',
                uploading: false,
              }),
            ),
          );

          await expectDocumentAfterTransaction({
            number: 2,
            expectedDoc,
            action: () => tiptapEditor.commands.uploadAttachment({ file }),
          });
        });
      });

      describe('when uploading request fails', () => {
        beforeEach(() => {
          mock.onPost().reply(httpStatus.INTERNAL_SERVER_ERROR);
        });

        it('resets the doc to original state', async () => {
          const expectedDoc = doc(p(''));

          await expectDocumentAfterTransaction({
            number: 2,
            expectedDoc,
            action: () => tiptapEditor.commands.uploadAttachment({ file }),
          });
        });

        it('emits an alert event that includes an error message', () => {
          tiptapEditor.commands.uploadAttachment({ file });

          return new Promise((resolve) => {
            eventHub.$on('alert', ({ message, variant }) => {
              expect(variant).toBe(VARIANT_DANGER);
              expect(message).toBe('An error occurred while uploading the file. Please try again.');
              resolve();
            });
          });
        });
      });
    });

    describe('when the file has a zip (or any other attachment) mime type', () => {
      const markdownApiResult = PROJECT_WIKI_ATTACHMENT_LINK_HTML;

      beforeEach(() => {
        renderMarkdown.mockResolvedValue(markdownApiResult);
      });

      describe('when uploading succeeds', () => {
        const successResponse = {
          link: {
            markdown: '[test-file](test-file.zip)',
          },
        };

        beforeEach(() => {
          mock.onPost().reply(httpStatus.OK, successResponse);
        });

        it('inserts a loading mark', async () => {
          const expectedDoc = doc(p(loading({ label: 'test-file' })));

          await expectDocumentAfterTransaction({
            number: 1,
            expectedDoc,
            action: () => tiptapEditor.commands.uploadAttachment({ file: attachmentFile }),
          });
        });

        it('updates the loading mark with a link with canonicalSrc and href attrs', async () => {
          const [, group, project] = markdownApiResult.match(/\/(group[0-9]+)\/(project[0-9]+)\//);
          const expectedDoc = doc(
            p(
              link(
                {
                  canonicalSrc: 'test-file.zip',
                  href: `/${group}/${project}/-/wikis/test-file.zip`,
                },
                'test-file',
              ),
            ),
          );

          await expectDocumentAfterTransaction({
            number: 2,
            expectedDoc,
            action: () => tiptapEditor.commands.uploadAttachment({ file: attachmentFile }),
          });
        });
      });

      describe('when uploading request fails', () => {
        beforeEach(() => {
          mock.onPost().reply(httpStatus.INTERNAL_SERVER_ERROR);
        });

        it('resets the doc to orginal state', async () => {
          const expectedDoc = doc(p(''));

          await expectDocumentAfterTransaction({
            number: 2,
            expectedDoc,
            action: () => tiptapEditor.commands.uploadAttachment({ file: attachmentFile }),
          });
        });

        it('emits an alert event that includes an error message', () => {
          tiptapEditor.commands.uploadAttachment({ file: attachmentFile });

          eventHub.$on('alert', ({ message, variant }) => {
            expect(variant).toBe(VARIANT_DANGER);
            expect(message).toBe('An error occurred while uploading the file. Please try again.');
          });
        });
      });
    });
  });
});
