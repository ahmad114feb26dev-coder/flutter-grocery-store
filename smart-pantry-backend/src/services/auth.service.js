const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const User = require('../models/User');
const env = require('../config/env');
const AppError = require('../utils/AppError');

const signAccessToken = (userId) => {
  return jwt.sign({ id: userId }, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_EXPIRES_IN,
  });
};

const signRefreshToken = (userId) => {
  return jwt.sign({ id: userId }, env.JWT_REFRESH_SECRET, {
    expiresIn: env.JWT_REFRESH_EXPIRES_IN,
  });
};

const registerUser = async ({ name, email, password }) => {
  const existingUser = await User.findOne({ email });
  if (existingUser) {
    throw new AppError('Email already in use', 409);
  }

  const salt = await bcrypt.genSalt(12);
  const passwordHash = await bcrypt.hash(password, salt);

  const user = await User.create({
    name,
    email,
    passwordHash,
  });

  return user;
};

const loginUser = async ({ email, password }) => {
  const cleanEmail = (email || '').trim().toLowerCase();
  const user = await User.findOne({ email: cleanEmail });
  if (!user) {
    throw new AppError('Invalid User ID or password', 401);
  }

  const isMatch = await bcrypt.compare(password, user.passwordHash);
  if (!isMatch) {
    throw new AppError('Invalid User ID or password', 401);
  }

  return user;
};

const generateTokens = async (user) => {
  const accessToken = signAccessToken(user._id);
  const refreshToken = signRefreshToken(user._id);

  // Store hashed refresh token for rotation
  const salt = await bcrypt.genSalt(12);
  user.refreshTokenHash = await bcrypt.hash(refreshToken, salt);
  await user.save();

  return { accessToken, refreshToken };
};

const refreshAuthToken = async (refreshToken) => {
  try {
    const decoded = jwt.verify(refreshToken, env.JWT_REFRESH_SECRET);
    const user = await User.findById(decoded.id);

    if (!user || !user.refreshTokenHash) {
      throw new AppError('Invalid refresh token', 403);
    }

    const isMatch = await bcrypt.compare(refreshToken, user.refreshTokenHash);
    if (!isMatch) {
      // Possible reuse of old token, invalidate
      user.refreshTokenHash = null;
      await user.save();
      throw new AppError('Invalid refresh token', 403);
    }

    return generateTokens(user);
  } catch (err) {
    throw new AppError('Invalid or expired refresh token', 403);
  }
};

const logoutUser = async (userId) => {
  await User.findByIdAndUpdate(userId, { refreshTokenHash: null });
};

module.exports = {
  registerUser,
  loginUser,
  generateTokens,
  refreshAuthToken,
  logoutUser,
};
