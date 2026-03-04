// tests/unit/userMock.test.js
jest.mock('../../models/User');
const User = require('../../models/User');

describe('User Model Mock Test', () => {
  it('should save a user (mocked)', async () => {
    User.mockImplementationOnce(() => ({
      save: jest.fn().mockResolvedValue({ name: 'trump', email: 'trump@gmail.com' })
    }));

    const user = new User();
    await expect(user.save()).resolves.toEqual({ name: 'trump', email: 'trump@gmail.com' });
  });
});
