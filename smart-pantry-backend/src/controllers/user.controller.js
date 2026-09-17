const userService = require('../services/user.service');
const asyncHandler = require('../utils/asyncHandler');

const getUsers = asyncHandler(async (req, res) => {
  const users = await userService.listUsers(req.user.id);
  res.status(200).json({
    status: 'success',
    data: { users },
  });
});

const createUser = asyncHandler(async (req, res) => {
  const user = await userService.createUser({
    ...req.body,
    createdBy: req.user.id,
  });
  res.status(201).json({
    status: 'success',
    data: { user },
  });
});

const updateUser = asyncHandler(async (req, res) => {
  const user = await userService.updateUser(req.params.id, req.body);
  const io = req.app.get('io');
  if (io) {
    const userIdStr = user.id ? user.id.toString() : req.params.id;
    io.emit('user_permissions_updated', { user });
    io.to(userIdStr).emit('user_permissions_updated', { user });
    io.to('pantry_store').emit('user_permissions_updated', { user });
  }
  res.status(200).json({
    status: 'success',
    data: { user },
  });
});

const deleteUser = asyncHandler(async (req, res) => {
  await userService.deleteUser(req.params.id, req.user.id);
  res.status(204).json({
    status: 'success',
    data: null,
  });
});

module.exports = {
  getUsers,
  createUser,
  updateUser,
  deleteUser,
};
