// tests/integration/userRoutes.test.js
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

describe('User Route Integration Test', () => {
  it('should create a new user', async () => {
    const res = await request(app).post('/users').send({ name: 'Trump', email: 'trump@gmail.com' });
    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('_id');
  });

  it('should fetch all users', async () => {
    const res = await request(app).get('/users');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBeTruthy();
  });
});
