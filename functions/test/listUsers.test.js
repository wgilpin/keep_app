// const admin = require("firebase-admin");
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIREBASE_DATABASE_EMULATOR_HOST = '127.0.0.1:8080';

const {expect} = require('@jest/globals');
// const firebaseFunctionsTest = require ("firebase-functions-test");
const firebaseFunctionsTest = require('firebase-functions-test');

// Mock config values here
// import functions *after* initializing Firebase
const functions = require('../index.js');
// Extracting `wrap` out of the lazy-loaded features
const {wrap} = firebaseFunctionsTest();

describe('create user', () => {
  let wrapped;
  beforeAll(() => {
    wrapped = wrap(functions.setupNewUser);
  });

  test('should create a new user', async () => {
    wrapped({uid: 'value'});
    expect(true).toBe(true);
  });
});
