const authService = require('../services/auth.service');
const asyncHandler = require('../utils/asyncHandler');
const { getStoreOwnerId } = require('../utils/storeHelper');

const register = asyncHandler(async (req, res, next) => {
  const user = await authService.registerUser(req.body);
  const tokens = await authService.generateTokens(user);
  const storeOwnerId = await getStoreOwnerId(user);

  res.status(201).json({
    status: 'success',
    data: {
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role || 'admin',
        allowedSections: user.allowedSections || ['dashboard', 'pantry', 'expenses', 'reports', 'shopping_list'],
        accessMode: user.accessMode || (user.role === 'admin' ? 'can_edit' : 'view_only'),
        shiftType: user.shiftType || 'all_day',
        shiftStartTime: user.shiftStartTime || null,
        shiftEndTime: user.shiftEndTime || null,
        storeOwnerId: storeOwnerId ? storeOwnerId.toString() : user._id.toString(),
      },
      tokens,
    },
  });
});

const login = asyncHandler(async (req, res, next) => {
  const user = await authService.loginUser(req.body);
  const tokens = await authService.generateTokens(user);
  const storeOwnerId = await getStoreOwnerId(user);

  res.status(200).json({
    status: 'success',
    data: {
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role || 'admin',
        allowedSections: user.allowedSections || ['dashboard', 'pantry', 'expenses', 'reports', 'shopping_list'],
        accessMode: user.accessMode || (user.role === 'admin' ? 'can_edit' : 'view_only'),
        shiftType: user.shiftType || 'all_day',
        shiftStartTime: user.shiftStartTime || null,
        shiftEndTime: user.shiftEndTime || null,
        storeOwnerId: storeOwnerId ? storeOwnerId.toString() : user._id.toString(),
      },
      tokens,
    },
  });
});

const refreshToken = asyncHandler(async (req, res, next) => {
  const tokens = await authService.refreshAuthToken(req.body.refreshToken);

  res.status(200).json({
    status: 'success',
    data: { tokens },
  });
});

const logout = asyncHandler(async (req, res, next) => {
  await authService.logoutUser(req.user.id);
  res.status(200).json({ status: 'success', message: 'Logged out successfully' });
});

const getMe = asyncHandler(async (req, res, next) => {
  const storeOwnerId = await getStoreOwnerId(req.user);

  res.status(200).json({
    status: 'success',
    data: {
      user: {
        id: req.user._id,
        name: req.user.name,
        email: req.user.email,
        role: req.user.role || 'admin',
        allowedSections: req.user.allowedSections || ['dashboard', 'pantry', 'expenses', 'reports', 'shopping_list'],
        accessMode: req.user.accessMode || (req.user.role === 'admin' ? 'can_edit' : 'view_only'),
        shiftType: req.user.shiftType || 'all_day',
        shiftStartTime: req.user.shiftStartTime || null,
        shiftEndTime: req.user.shiftEndTime || null,
        storeOwnerId: storeOwnerId ? storeOwnerId.toString() : req.user._id.toString(),
      },
    },
  });
});

module.exports = {
  register,
  login,
  refreshToken,
  logout,
  getMe,
};
