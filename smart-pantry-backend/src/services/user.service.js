const bcrypt = require('bcrypt');
const User = require('../models/User');
const AppError = require('../utils/AppError');

const listUsers = async (currentUserId) => {
  return await User.find({ _id: { $ne: currentUserId } })
    .select('-passwordHash -refreshTokenHash')
    .sort({ createdAt: -1 });
};

const createUser = async ({
  name,
  email,
  password,
  allowedSections,
  role = 'user',
  accessMode = 'view_only',
  shiftType = 'all_day',
  shiftStartTime = null,
  shiftEndTime = null,
  createdBy,
}) => {
  const existingUser = await User.findOne({ email: email.toLowerCase().trim() });
  if (existingUser) {
    throw new AppError('A user with this User ID / Email already exists', 409);
  }

  const salt = await bcrypt.genSalt(12);
  const passwordHash = await bcrypt.hash(password, salt);

  const sections = Array.isArray(allowedSections) && allowedSections.length > 0
    ? allowedSections
    : ['shopping_list']; // Default to at least shopping list if none provided

  const user = await User.create({
    name: name.trim(),
    email: email.toLowerCase().trim(),
    passwordHash,
    role: role || 'user',
    allowedSections: sections,
    accessMode: accessMode || 'view_only',
    shiftType: shiftType || 'all_day',
    shiftStartTime: shiftStartTime || null,
    shiftEndTime: shiftEndTime || null,
    createdBy: createdBy || null,
  });

  return {
    id: user._id,
    name: user.name,
    email: user.email,
    role: user.role,
    allowedSections: user.allowedSections,
    accessMode: user.accessMode,
    shiftType: user.shiftType,
    shiftStartTime: user.shiftStartTime,
    shiftEndTime: user.shiftEndTime,
    createdAt: user.createdAt,
  };
};

const updateUser = async (userId, updateData) => {
  const user = await User.findById(userId);
  if (!user) {
    throw new AppError('User not found', 404);
  }

  if (updateData.name) {
    user.name = updateData.name.trim();
  }
  if (updateData.email) {
    const existing = await User.findOne({ email: updateData.email.toLowerCase().trim(), _id: { $ne: userId } });
    if (existing) {
      throw new AppError('Email already taken by another user', 409);
    }
    user.email = updateData.email.toLowerCase().trim();
  }
  if (updateData.password && updateData.password.length >= 4) {
    const salt = await bcrypt.genSalt(12);
    user.passwordHash = await bcrypt.hash(updateData.password, salt);
  }
  if (updateData.allowedSections && Array.isArray(updateData.allowedSections)) {
    user.allowedSections = updateData.allowedSections;
  }
  if (updateData.role) {
    user.role = updateData.role;
  }
  if (updateData.accessMode) {
    user.accessMode = updateData.accessMode;
  }
  if (updateData.shiftType !== undefined) {
    user.shiftType = updateData.shiftType;
  }
  if (updateData.shiftStartTime !== undefined) {
    user.shiftStartTime = updateData.shiftStartTime;
  }
  if (updateData.shiftEndTime !== undefined) {
    user.shiftEndTime = updateData.shiftEndTime;
  }

  await user.save();

  return {
    id: user._id,
    name: user.name,
    email: user.email,
    role: user.role,
    allowedSections: user.allowedSections,
    accessMode: user.accessMode,
    shiftType: user.shiftType,
    shiftStartTime: user.shiftStartTime,
    shiftEndTime: user.shiftEndTime,
    updatedAt: user.updatedAt,
  };
};

const deleteUser = async (userId, currentUserId) => {
  if (userId.toString() === currentUserId.toString()) {
    throw new AppError('You cannot delete your own admin account', 400);
  }
  const deleted = await User.findByIdAndDelete(userId);
  if (!deleted) {
    throw new AppError('User not found', 404);
  }
  return true;
};

module.exports = {
  listUsers,
  createUser,
  updateUser,
  deleteUser,
};
