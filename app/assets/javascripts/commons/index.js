import 'underscore';
import './polyfills';
import './jquery';
import './bootstrap';
import './vue';
import '../lib/utils/axios_utils';
import { openUserCountsBroadcast } from './nav/user_merge_requests';

openUserCountsBroadcast();
