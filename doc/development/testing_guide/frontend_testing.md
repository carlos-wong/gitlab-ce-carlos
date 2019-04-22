# Frontend testing standards and style guidelines

There are two types of test suites you'll encounter while developing frontend code
at GitLab. We use Karma and Jasmine for JavaScript unit and integration testing,
and RSpec feature tests with Capybara for e2e (end-to-end) integration testing.

Unit and feature tests need to be written for all new features.
Most of the time, you should use [RSpec] for your feature tests.

Regression tests should be written for bug fixes to prevent them from recurring
in the future.

See the [Testing Standards and Style Guidelines](index.md) page for more
information on general testing practices at GitLab.

## Jest

GitLab has started to migrate tests to the [Jest](https://jestjs.io)
testing framework. You can read a [detailed evaluation](https://gitlab.com/gitlab-org/gitlab-ce/issues/49171)
of Jest compared to our use of Karma and Jasmine. In summary, it will allow us
to improve the performance and consistency of our frontend tests.

Jest tests can be found in `/spec/frontend` and `/ee/spec/frontend` in EE.

It is not yet a requirement to use Jest. You can view the
[epic](https://gitlab.com/groups/gitlab-org/-/epics/873) of issues
we need to solve before being able to use Jest for all our needs.

### Debugging Jest tests

Running `yarn jest-debug` will run Jest in debug mode, allowing you to debug/inspect as described in the [Jest docs](https://jestjs.io/docs/en/troubleshooting#tests-are-failing-and-you-don-t-know-why).

### Timeout error

The default timeout for Jest is set in
[`/spec/frontend/test_setup.js`](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/spec/frontend/test_setup.js).

If your test exceeds that time, it will fail.

If you cannot improve the performance of the tests, you can increase the timeout
for a specific test using
[`setTestTimeout`](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/spec/frontend/helpers/timeout.js).

```javascript
import { setTestTimeout } from 'helpers/timeout';

describe('Component', () => {
  it('does something amazing', () => {
    setTestTimeout(500);
    // ...
  });
});
```

Remember that the performance of each test depends on the environment.

## Karma test suite

GitLab uses the [Karma][karma] test runner with [Jasmine] as its test
framework for our JavaScript unit and integration tests.
We generate HTML and JSON fixtures from backend views and controllers
using RSpec (see `spec/javascripts/fixtures/*.rb` for examples).
Fixtures are served during testing by the [jasmine-jquery][jasmine-jquery] plugin.

JavaScript tests live in `spec/javascripts/`, matching the folder structure
of `app/assets/javascripts/`: `app/assets/javascripts/behaviors/autosize.js`
has a corresponding `spec/javascripts/behaviors/autosize_spec.js` file.

Keep in mind that in a CI environment, these tests are run in a headless
browser and you will not have access to certain APIs, such as
[`Notification`](https://developer.mozilla.org/en-US/docs/Web/API/notification),
which will have to be stubbed.

### Best practices

#### Naming unit tests

When writing describe test blocks to test specific functions/methods,
please use the method name as the describe block name.

```javascript
// Good
describe('methodName', () => {
  it('passes', () => {
    expect(true).toEqual(true);
  });
});

// Bad
describe('#methodName', () => {
  it('passes', () => {
    expect(true).toEqual(true);
  });
});

// Bad
describe('.methodName', () => {
  it('passes', () => {
    expect(true).toEqual(true);
  });
});
```

#### Testing promises

When testing Promises you should always make sure that the test is asynchronous and rejections are handled.
Your Promise chain should therefore end with a call of the `done` callback and `done.fail` in case an error occurred.

```javascript
// Good
it('tests a promise', done => {
  promise
    .then(data => {
      expect(data).toBe(asExpected);
    })
    .then(done)
    .catch(done.fail);
});

// Good
it('tests a promise rejection', done => {
  promise
    .then(done.fail)
    .catch(error => {
      expect(error).toBe(expectedError);
    })
    .then(done)
    .catch(done.fail);
});

// Bad (missing done callback)
it('tests a promise', () => {
  promise.then(data => {
    expect(data).toBe(asExpected);
  });
});

// Bad (missing catch)
it('tests a promise', done => {
  promise
    .then(data => {
      expect(data).toBe(asExpected);
    })
    .then(done);
});

// Bad (use done.fail in asynchronous tests)
it('tests a promise', done => {
  promise
    .then(data => {
      expect(data).toBe(asExpected);
    })
    .then(done)
    .catch(fail);
});

// Bad (missing catch)
it('tests a promise rejection', done => {
  promise
    .catch(error => {
      expect(error).toBe(expectedError);
    })
    .then(done);
});
```

#### Stubbing and Mocking

Jasmine provides useful helpers `spyOn`, `spyOnProperty`, `jasmine.createSpy`,
and `jasmine.createSpyObject` to facilitate replacing methods with dummy
placeholders, and recalling when they are called and the arguments that are
passed to them. These tools should be used liberally, to test for expected
behavior, to mock responses, and to block unwanted side effects (such as a
method that would generate a network request or alter `window.location`). The
documentation for these methods can be found in the [Jasmine introduction page](https://jasmine.github.io/2.0/introduction.html#section-Spies).

Sometimes you may need to spy on a method that is directly imported by another
module. GitLab has a custom `spyOnDependency` method which utilizes
[babel-plugin-rewire](https://github.com/speedskater/babel-plugin-rewire) to
achieve this. It can be used like so:

```js
// my_module.js
import { visitUrl } from '~/lib/utils/url_utility';

export default function doSomething() {
  visitUrl('/foo/bar');
}
```
```js
// my_module_spec.js
import doSomething from '~/my_module';

describe('my_module', () => {
  it('does something', () => {
    const visitUrl = spyOnDependency(doSomething, 'visitUrl');

    doSomething();
    expect(visitUrl).toHaveBeenCalledWith('/foo/bar');
  });
});
```

Unlike `spyOn`, `spyOnDependency` expects its first parameter to be the default
export of a module who's import you want to stub, rather than an object which
contains a method you wish to stub (if the module does not have a default
export, one is be generated by the babel plugin). The second parameter is the
name of the import you wish to change. The result of the function is a Spy
object which can be treated like any other Jasmine spy object.

Further documentation on the babel rewire pluign API can be found on
[its repository Readme doc](https://github.com/speedskater/babel-plugin-rewire#babel-plugin-rewire).

#### Waiting in tests

If you cannot avoid using [`setTimeout`](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/setTimeout) in tests, please use the [Jasmine mock clock](https://jasmine.github.io/api/2.9/Clock.html).

#### Migrating flaky Karma tests to Jest

Some of our Karma tests are flaky because they access the properties of a shared scope.
This also means that they are not easily parallelized.

Migrating flaky Karma tests to Jest will help significantly as each test is executed
in an isolated scope, improving performance and predictability.

### Vue.js unit tests

See this [section][vue-test].

### Running frontend tests

For running the frontend tests, you need the following commands:

- `rake karma:fixtures` (re-)generates fixtures.
- `yarn test` executes the tests.

As long as the fixtures don't change, `yarn test` is sufficient (and saves you some time).

### Live testing and focused testing

While developing locally, it may be helpful to keep Karma running so that you
can get instant feedback on as you write tests and modify code. To do this
you can start Karma with `yarn run karma-start`. It will compile the javascript
assets and run a server at `http://localhost:9876/` where it will automatically
run the tests on any browser which connects to it. You can enter that url on
multiple browsers at once to have it run the tests on each in parallel.

While Karma is running, any changes you make will instantly trigger a recompile
and retest of the entire test suite, so you can see instantly if you've broken
a test with your changes. You can use [Jasmine focused][jasmine-focus] or
excluded tests (with `fdescribe` or `xdescribe`) to get Karma to run only the
tests you want while you're working on a specific feature, but make sure to
remove these directives when you commit your code.

It is also possible to only run Karma on specific folders or files by filtering
the run tests via the argument `--filter-spec` or short `-f`:

```bash
# Run all files
yarn karma-start
# Run specific spec files
yarn karma-start --filter-spec profile/account/components/update_username_spec.js
# Run specific spec folder
yarn karma-start --filter-spec profile/account/components/
# Run all specs which path contain vue_shared or vie
yarn karma-start -f vue_shared -f vue_mr_widget
```

You can also use glob syntax to match files. Remember to put quotes around the
glob otherwise your shell may split it into multiple arguments:

```bash
# Run all specs named `file_spec` within the IDE subdirectory
yarn karma -f 'spec/javascripts/ide/**/file_spec.js'
```

## RSpec feature integration tests

Information on setting up and running RSpec integration tests with
[Capybara] can be found in the [Testing Best Practices](best_practices.md).

## Gotchas

### RSpec errors due to JavaScript

By default RSpec unit tests will not run JavaScript in the headless browser
and will simply rely on inspecting the HTML generated by rails.

If an integration test depends on JavaScript to run correctly, you need to make
sure the spec is configured to enable JavaScript when the tests are run. If you
don't do this you'll see vague error messages from the spec runner.

To enable a JavaScript driver in an `rspec` test, add `:js` to the
individual spec or the context block containing multiple specs that need
JavaScript enabled:

```ruby
# For one spec
it 'presents information about abuse report', :js do
  # assertions...
end

describe "Admin::AbuseReports", :js do
  it 'presents information about abuse report' do
    # assertions...
  end
  it 'shows buttons for adding to abuse report' do
    # assertions...
  end
end
```

[jasmine-focus]: https://jasmine.github.io/2.5/focused_specs.html
[jasmine-jquery]: https://github.com/velesin/jasmine-jquery
[karma]: http://karma-runner.github.io/
[vue-test]: https://docs.gitlab.com/ce/development/fe_guide/vue.html#testing-vue-components
[rspec]: https://github.com/rspec/rspec-rails#feature-specs
[capybara]: https://github.com/teamcapybara/capybara
[karma]: http://karma-runner.github.io/
[jasmine]: https://jasmine.github.io/

---

[Return to Testing documentation](index.md)
