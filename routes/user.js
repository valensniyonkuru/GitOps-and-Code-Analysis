// routes/user.js
const express = require('express');
const User = require('../models/User');
const router = express.Router();

router.post('/', async (req, res) => {
  const user = new User(req.body);
  await user.save();
  res.status(201).send(user);
});

router.get('/', async (req, res) => {
  const users = await User.find({});
  res.status(200).send(users);
});

module.exports = router;
