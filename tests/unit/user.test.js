const User = require('../../models/User');
// const mongoose = require('mongoose');

// Example of a unit test for User model
describe('User Model Unit Test', () => {
  it('should create a user correctly', async () => {
    const user = new User({ name: 'Trump', email: 'trump@gmail.com' });
    expect(user.name).toBe('Trump');
    expect(user.email).toBe('trump@gmail.com');
  });
});
