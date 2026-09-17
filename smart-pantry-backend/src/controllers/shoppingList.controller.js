const shoppingListService = require('../services/shoppingList.service');
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../utils/AppError');
const { getStoreOwnerId, canUserEdit } = require('../utils/storeHelper');

const getShoppingList = asyncHandler(async (req, res, next) => {
  const storeOwnerId = await getStoreOwnerId(req.user);
  const items = await shoppingListService.getShoppingList(storeOwnerId);
  res.status(200).json({
    status: 'success',
    data: { items },
  });
});

const addItem = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot add items until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  const item = await shoppingListService.addItem(storeOwnerId, req.body);
  res.status(201).json({
    status: 'success',
    data: { item },
  });
});

const updateItem = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot edit items until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  const item = await shoppingListService.updateItem(storeOwnerId, req.params.id, req.body);
  res.status(200).json({
    status: 'success',
    data: { item },
  });
});

const deleteItem = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot delete items until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  await shoppingListService.deleteItem(storeOwnerId, req.params.id);
  res.status(204).json({
    status: 'success',
    data: null,
  });
});

const finalizeList = asyncHandler(async (req, res, next) => {
  if (!canUserEdit(req.user)) {
    throw new AppError('You have View-Only access. You cannot finalize lists until Admin grants edit access.', 403);
  }
  const storeOwnerId = await getStoreOwnerId(req.user);
  const items = await shoppingListService.finalizeShoppingList(storeOwnerId, {
    ids: req.body.ids,
    isFrozen: req.body.isFrozen !== undefined ? req.body.isFrozen : true,
  });
  res.status(200).json({
    status: 'success',
    data: { items },
  });
});

module.exports = {
  getShoppingList,
  addItem,
  updateItem,
  deleteItem,
  finalizeList,
};
