const inventoryService = require('../services/inventory.service');
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../utils/AppError');
const { calculateDaysLeft } = require('../utils/dateUtils');
const { getStoreOwnerId, canUserEdit, isUserWithinShift, getShiftDisplay } = require('../utils/storeHelper');

const getInventory = asyncHandler(async (req, res, next) => {
  const storeOwnerId = await getStoreOwnerId(req.user);
  const result = await inventoryService.getInventory(storeOwnerId, req.query);

  // Compute daysLeft dynamically for the frontend
  const ingredientsWithComputedFields = result.ingredients.map((ing) => {
    const obj = ing.toObject();
    obj.daysLeft = calculateDaysLeft(obj.expiryDate);
    return obj;
  });

  res.status(200).json({
    status: 'success',
    data: {
      ...result,
      ingredients: ingredientsWithComputedFields,
    },
  });
});

const addIngredient = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot add ingredients until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  const ingredient = await inventoryService.addIngredient(storeOwnerId, req.body);
  const obj = ingredient.toObject();
  obj.daysLeft = calculateDaysLeft(obj.expiryDate);

  const io = req.app.get('io');
  if (io) {
    io.to(storeOwnerId.toString()).emit('inventory_item_added', { ingredient: obj });
    io.emit('inventory_item_added', { ingredient: obj });
  }

  res.status(201).json({
    status: 'success',
    data: { ingredient: obj },
  });
});

const updateIngredient = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot edit ingredients until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  const ingredient = await inventoryService.updateIngredient(storeOwnerId, req.params.id, req.body);
  const obj = ingredient.toObject();
  obj.daysLeft = calculateDaysLeft(obj.expiryDate);

  const io = req.app.get('io');
  if (io) {
    io.to(storeOwnerId.toString()).emit('inventory_item_updated', { ingredient: obj });
    io.emit('inventory_item_updated', { ingredient: obj });
  }

  res.status(200).json({
    status: 'success',
    data: { ingredient: obj },
  });
});

const deleteIngredient = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot delete ingredients until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  await inventoryService.deleteIngredient(storeOwnerId, req.params.id);

  const io = req.app.get('io');
  if (io) {
    io.to(storeOwnerId.toString()).emit('inventory_item_deleted', { id: req.params.id });
    io.emit('inventory_item_deleted', { id: req.params.id });
  }

  res.status(204).json({
    status: 'success',
    data: null,
  });
});

const restockIngredient = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot restock ingredients until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  const addedQuantity = req.body.addedQuantity != null ? req.body.addedQuantity : req.body.quantity;
  const ingredient = await inventoryService.restockIngredient(storeOwnerId, req.params.id, addedQuantity);
  const obj = ingredient.toObject();
  obj.daysLeft = calculateDaysLeft(obj.expiryDate);

  const io = req.app.get('io');
  if (io) {
    io.to(storeOwnerId.toString()).emit('inventory_item_updated', { ingredient: obj });
    io.emit('inventory_item_updated', { ingredient: obj });
  }

  res.status(200).json({
    status: 'success',
    data: { ingredient: obj },
  });
});

const logUsage = asyncHandler(async (req, res, next) => {
  if (!isUserWithinShift(req.user)) {
    const shiftInfo = getShiftDisplay(req.user);
    throw new AppError(`Aap ki shift ka waqt nahi hai. Aap ko sirf ${shiftInfo} ke dauran data enter karne ki ijazat hai.`, 403);
  }

  const storeOwnerId = await getStoreOwnerId(req.user);
  const { dayOfMonth, amount, isOverwrite, reason } = req.body;
  const isUserAdmin = req.user && req.user.role === 'admin';

  const ingredient = await inventoryService.logUsage(storeOwnerId, req.params.id, {
    dayOfMonth,
    amount,
    isOverwrite,
    isAdmin: isUserAdmin,
    reason: reason || '',
    updatedBy: {
      id: req.user._id,
      name: req.user.name || 'Admin',
      email: req.user.email || '',
      shiftType: req.user.shiftType || 'all_day',
      shiftLabel: getShiftDisplay(req.user),
    },
  });

  const obj = ingredient.toObject();
  obj.daysLeft = calculateDaysLeft(obj.expiryDate);

  // Emit real-time Socket.IO event to store room
  const io = req.app.get('io');
  if (io) {
    const payload = {
      ingredientId: ingredient._id,
      ingredientName: ingredient.name,
      dayOfMonth: dayOfMonth || new Date().getDate(),
      amount: Number(amount) || 0,
      unit: ingredient.unit || '',
      loggedBy: {
        id: req.user._id,
        name: req.user.name || 'Staff User',
        email: req.user.email || '',
        role: req.user.role || 'user',
        shiftType: req.user.shiftType || 'all_day',
        shiftLabel: getShiftDisplay(req.user),
      },
      updatedIngredient: obj,
      timestamp: new Date().toISOString(),
    };

    // Emit to store room and broadcast globally to connected clients
    io.to(storeOwnerId.toString()).emit('inventory_usage_logged', payload);
    io.emit('inventory_usage_logged', payload);
    console.log(`[Socket.IO] Emitted inventory_usage_logged for "${ingredient.name}" by ${req.user.name}`);
  }

  res.status(200).json({
    status: 'success',
    data: { ingredient: obj },
  });
});

const clearMonthDays = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot clear daily logs until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  const ingredients = await inventoryService.clearMonthDays(storeOwnerId);

  const ingredientsWithComputedFields = ingredients.map((ing) => {
    const obj = ing.toObject();
    obj.daysLeft = calculateDaysLeft(obj.expiryDate);
    obj.dailyUsageLogs = {};
    obj.totalUsed = 0;
    return obj;
  });

  const io = req.app.get('io');
  if (io) {
    const payload = {
      clearedBy: {
        id: req.user._id,
        name: req.user.name || 'Admin',
        email: req.user.email || '',
        role: req.user.role || 'admin',
      },
      updatedIngredients: ingredientsWithComputedFields,
      timestamp: new Date().toISOString(),
    };
    io.to(storeOwnerId.toString()).emit('inventory_cleared_days', payload);
    io.to('pantry_store').emit('inventory_cleared_days', payload);
    io.emit('inventory_cleared_days', payload);
    console.log(`[Socket.IO] Emitted inventory_cleared_days to store ${storeOwnerId} and pantry_store by ${req.user.name}`);
  }

  res.status(200).json({
    status: 'success',
    message: 'All daily logs have been cleared and balance restored to stock in.',
    data: { ingredients: ingredientsWithComputedFields },
  });
});

const closeMonth = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot close months until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  const { monthYear, force } = req.body;
  const result = await inventoryService.closeMonth(storeOwnerId, { monthYear, force: Boolean(force) });

  const ingredientsWithComputedFields = result.newIngredients.map((ing) => {
    const obj = ing.toObject();
    obj.daysLeft = calculateDaysLeft(obj.expiryDate);
    return obj;
  });

  const io = req.app.get('io');
  if (io) {
    const payload = {
      closedBy: {
        id: req.user._id,
        name: req.user.name || 'Admin',
        email: req.user.email || '',
        role: req.user.role || 'admin',
      },
      monthYear,
      newIngredients: ingredientsWithComputedFields,
      archive: result.archive,
      timestamp: new Date().toISOString(),
    };
    io.to(storeOwnerId.toString()).emit('inventory_month_closed', payload);
    io.to('pantry_store').emit('inventory_month_closed', payload);
    io.emit('inventory_month_closed', payload);
    console.log(`[Socket.IO] Emitted inventory_month_closed by ${req.user.name}`);
  }

  res.status(200).json({
    status: 'success',
    message: `Month ${monthYear || ''} closed successfully. Closing balance carried forward as new Stock In.`,
    data: {
      ...result,
      newIngredients: ingredientsWithComputedFields,
    },
  });
});

const getMonthlyArchives = asyncHandler(async (req, res, next) => {
  const storeOwnerId = await getStoreOwnerId(req.user);
  const archives = await inventoryService.getMonthlyArchives(storeOwnerId);
  res.status(200).json({
    status: 'success',
    data: { archives },
  });
});

const deleteMonthlyArchive = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot delete archives until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  await inventoryService.deleteMonthlyArchive(storeOwnerId, req.params.id);
  res.status(200).json({
    status: 'success',
    message: 'Archived statement deleted successfully.',
  });
});

module.exports = {
  getInventory,
  addIngredient,
  updateIngredient,
  deleteIngredient,
  restockIngredient,
  logUsage,
  clearMonthDays,
  closeMonth,
  getMonthlyArchives,
  deleteMonthlyArchive,
};
