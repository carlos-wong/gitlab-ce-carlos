import { editor as monacoEditor, Uri } from 'monaco-editor';
import Disposable from './disposable';
import eventHub from '../../eventhub';

export default class Model {
  constructor(file, head = null) {
    this.disposable = new Disposable();
    this.file = file;
    this.head = head;
    this.content = file.content !== '' || file.deleted ? file.content : file.raw;

    this.disposable.add(
      (this.originalModel = monacoEditor.createModel(
        head ? head.content : this.file.raw,
        undefined,
        new Uri('gitlab', false, `original/${this.path}`),
      )),
      (this.model = monacoEditor.createModel(
        this.content,
        undefined,
        new Uri('gitlab', false, this.path),
      )),
    );
    if (this.file.mrChange) {
      this.disposable.add(
        (this.baseModel = monacoEditor.createModel(
          this.file.baseRaw,
          undefined,
          new Uri('gitlab', false, `target/${this.path}`),
        )),
      );
    }

    this.events = new Set();

    this.updateContent = this.updateContent.bind(this);
    this.updateNewContent = this.updateNewContent.bind(this);
    this.dispose = this.dispose.bind(this);

    eventHub.$on(`editor.update.model.dispose.${this.file.key}`, this.dispose);
    eventHub.$on(`editor.update.model.content.${this.file.key}`, this.updateContent);
    eventHub.$on(`editor.update.model.new.content.${this.file.key}`, this.updateNewContent);
  }

  get url() {
    return this.model.uri.toString();
  }

  get language() {
    return this.model.getModeId();
  }

  get eol() {
    return this.model.getEOL() === '\n' ? 'LF' : 'CRLF';
  }

  get path() {
    return this.file.key;
  }

  getModel() {
    return this.model;
  }

  getOriginalModel() {
    return this.originalModel;
  }

  getBaseModel() {
    return this.baseModel;
  }

  setValue(value) {
    this.getModel().setValue(value);
  }

  onChange(cb) {
    this.events.add(this.disposable.add(this.model.onDidChangeContent(e => cb(this, e))));
  }

  onDispose(cb) {
    this.events.add(cb);
  }

  updateContent({ content, changed }) {
    this.getOriginalModel().setValue(content);

    if (!changed) {
      this.getModel().setValue(content);
    }
  }

  updateNewContent(content) {
    this.getModel().setValue(content);
  }

  dispose() {
    this.disposable.dispose();

    this.events.forEach(cb => {
      if (typeof cb === 'function') cb();
    });

    this.events.clear();

    eventHub.$off(`editor.update.model.dispose.${this.file.key}`, this.dispose);
    eventHub.$off(`editor.update.model.content.${this.file.key}`, this.updateContent);
    eventHub.$off(`editor.update.model.new.content.${this.file.key}`, this.updateNewContent);
  }
}
