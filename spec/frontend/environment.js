/* eslint-disable import/no-commonjs */

const { ErrorWithStack } = require('jest-util');
const JSDOMEnvironment = require('jest-environment-jsdom');

class CustomEnvironment extends JSDOMEnvironment {
  constructor(config, context) {
    super(config, context);

    Object.assign(context.console, {
      error(...args) {
        throw new ErrorWithStack(
          `Unexpected call of console.error() with:\n\n${args.join(', ')}`,
          this.error,
        );
      },

      warn(...args) {
        throw new ErrorWithStack(
          `Unexpected call of console.warn() with:\n\n${args.join(', ')}`,
          this.warn,
        );
      },
    });

    const { testEnvironmentOptions } = config;
    const { IS_EE } = testEnvironmentOptions;
    this.global.gon = {
      ee: IS_EE,
    };

    this.rejectedPromises = [];

    this.global.promiseRejectionHandler = error => {
      this.rejectedPromises.push(error);
    };

    this.global.fixturesBasePath = `${process.cwd()}/${
      IS_EE ? 'ee/' : ''
    }spec/javascripts/fixtures`;

    // Not yet supported by JSDOM: https://github.com/jsdom/jsdom/issues/317
    this.global.document.createRange = () => ({
      setStart: () => {},
      setEnd: () => {},
      commonAncestorContainer: {
        nodeName: 'BODY',
        ownerDocument: this.global.document,
      },
    });
  }

  async teardown() {
    await new Promise(setImmediate);

    if (this.rejectedPromises.length > 0) {
      throw new ErrorWithStack(
        `Unhandled Promise rejections: ${this.rejectedPromises.join(', ')}`,
        this.teardown,
      );
    }

    await super.teardown();
  }
}

module.exports = CustomEnvironment;
