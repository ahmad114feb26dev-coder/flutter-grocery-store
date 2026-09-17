const ShoppingListItem = require('../models/ShoppingListItem');
const AppError = require('../utils/AppError');

const getShoppingList = async (userId) => {
  // Sort unresolved first, then by creation date
  return await ShoppingListItem.find({ userId }).sort({ resolved: 1, createdAt: -1 });
};

const addItem = async (userId, data) => {
  // Determine effective date of this item
  const itemDate = data.boughtAt
    ? new Date(data.boughtAt)
    : data.createdAt
    ? new Date(data.createdAt)
    : new Date();

  const startOfMonth = new Date(itemDate.getFullYear(), itemDate.getMonth(), 1);
  const endOfMonth = new Date(itemDate.getFullYear(), itemDate.getMonth() + 1, 0, 23, 59, 59, 999);

  // Find all items for this user in this month
  const monthItems = await ShoppingListItem.find({
    userId,
    $or: [
      { boughtAt: { $gte: startOfMonth, $lte: endOfMonth } },
      { createdAt: { $gte: startOfMonth, $lte: endOfMonth } },
    ],
  });

  // Calculate tripNumber: if all existing items in this month are frozen, start next trip!
  let tripNumber = data.tripNumber;
  if (!tripNumber) {
    const activeUnfrozenItem = monthItems.find((e) => !e.isFrozen);
    if (activeUnfrozenItem) {
      tripNumber = activeUnfrozenItem.tripNumber || 1;
    } else if (monthItems.length > 0) {
      const maxTrip = Math.max(...monthItems.map((e) => e.tripNumber || 1));
      tripNumber = maxTrip + 1;
    } else {
      tripNumber = 1;
    }
  }

  // Prevent exact duplicates ONLY if unresolved & unfrozen item exists in this same trip
  const existingItem = await ShoppingListItem.findOne({
    userId,
    ingredientName: data.ingredientName,
    resolved: false,
    isFrozen: false,
    tripNumber,
  });

  if (existingItem) {
    existingItem.quantityNeeded += data.quantityNeeded;
    return await existingItem.save();
  }

  return await ShoppingListItem.create({
    ...data,
    userId,
    tripNumber,
    isFrozen: false,
    addedReason: data.addedReason || 'manual',
  });
};

const updateItem = async (userId, itemId, updateData) => {
  const current = await ShoppingListItem.findOne({ _id: itemId, userId });
  if (!current) {
    throw new AppError('Shopping list item not found', 404);
  }

  // Once locked, it cannot be unlocked and quantity cannot be changed
  if (current.isFrozen) {
    if (updateData.isFrozen === false) {
      throw new AppError('Finalized items cannot be unlocked. Lock is permanent.', 400);
    }
    if (updateData.quantityNeeded !== undefined) {
      throw new AppError('Cannot modify quantity of a permanently locked shopping item', 400);
    }
  }

  // Once moved to pantry, item cannot be unchecked (must stay checked)
  if (current.movedToPantry && updateData.resolved === false) {
    throw new AppError('Cannot uncheck an item that has already been moved to pantry', 400);
  }

  if (updateData.resolved === true && !updateData.boughtAt) {
    updateData.boughtAt = new Date();
  } else if (updateData.resolved === false) {
    updateData.boughtAt = null;
  }

  const item = await ShoppingListItem.findOneAndUpdate(
    { _id: itemId, userId },
    updateData,
    { new: true, runValidators: true }
  );
  return item;
};

const deleteItem = async (userId, itemId) => {
  const current = await ShoppingListItem.findOne({ _id: itemId, userId });
  if (!current) {
    throw new AppError('Shopping list item not found', 404);
  }
  if (current.isFrozen) {
    throw new AppError('Cannot delete a permanently locked shopping item', 400);
  }
  return await ShoppingListItem.findOneAndDelete({ _id: itemId, userId });
};

const finalizeShoppingList = async (userId, { ids }) => {
  const filter = { userId };
  if (ids && Array.isArray(ids) && ids.length > 0) {
    filter._id = { $in: ids };
  }
  // Permanent lock - always set isFrozen to true
  await ShoppingListItem.updateMany(filter, { isFrozen: true });
  return await ShoppingListItem.find({ userId }).sort({ resolved: 1, createdAt: -1 });
};

module.exports = {
  getShoppingList,
  addItem,
  updateItem,
  deleteItem,
  finalizeShoppingList,
};
