// tests/e2e/userE2E.test.js
const request = require('supertest');
const { app, connectDB } = require('../../app');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await connectDB(mongoServer.getUri());
});

afterAll(async () => {
  await mongoose.connection.dropDatabase();
  await mongoose.connection.close();
  await mongoServer.stop();
});

describe('User End-to-End Test', () => {
  it('should create and fetch a user', async () => {
    const newUser = { name: 'Trump', email: 'trump@gmail.com' };
    const createRes = await request(app).post('/users').send(newUser);
    expect(createRes.statusCode).toBe(201);

    const fetchRes = await request(app).get('/users');
    expect(fetchRes.body.some(user => user.email === 'trump@gmail.com')).toBeTruthy();
  });
});
