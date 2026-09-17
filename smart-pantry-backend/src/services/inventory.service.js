const Ingredient = require('../models/Ingredient');
const MonthlyArchive = require('../models/MonthlyArchive');
const ShoppingListItem = require('../models/ShoppingListItem');
const AppError = require('../utils/AppError');

const getInventory = async (userId, { sort = 'expiryDate', order = 'asc', page = 1, limit = 50 }) => {
  const skip = (page - 1) * limit;
  const sortStage = { [sort]: order === 'desc' ? -1 : 1 };

  const ingredients = await Ingredient.find({ userId })
    .sort(sortStage)
    .skip(skip)
    .limit(limit);

  const total = await Ingredient.countDocuments({ userId });

  return {
    ingredients,
    total,
    page: parseInt(page),
    pages: Math.ceil(total / limit),
  };
};

const addIngredient = async (userId, data) => {
  const trimmedName = data.name.trim();
  const addedQty = Number(data.quantity) || 0;

  // Check if item with the same name already exists for this user (case-insensitive)
  const existing = await Ingredient.findOne({
    userId,
    name: { $regex: new RegExp(`^${trimmedName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') },
  });

  if (existing) {
    // Accumulate into existing stock
    existing.stockIn = (existing.stockIn != null ? existing.stockIn : existing.quantity) + addedQty;
    existing.quantity = (existing.stockIn || 0) - (existing.totalUsed || 0);
    if (data.expiryDate) existing.expiryDate = data.expiryDate;
    if (data.dailyUsage != null) existing.dailyUsage = data.dailyUsage;
    if (data.lowStockThreshold != null) existing.lowStockThreshold = data.lowStockThreshold;
    if (data.unit) existing.unit = data.unit;
    if (data.category && data.category !== 'Other') existing.category = data.category;
    await existing.save();
    return existing;
  }

  // Create new item
  const initialStockIn = data.stockIn != null ? Number(data.stockIn) : addedQty;
  const initialTotalUsed = Number(data.totalUsed) || 0;
  return await Ingredient.create({
    ...data,
    userId,
    stockIn: initialStockIn,
    totalUsed: initialTotalUsed,
    quantity: initialStockIn - initialTotalUsed,
    dailyUsageLogs: data.dailyUsageLogs || {},
  });
};

const restockIngredient = async (userId, ingredientId, addedQty) => {
  const ingredient = await Ingredient.findOne({ _id: ingredientId, userId });
  if (!ingredient) {
    throw new AppError('Ingredient not found', 404);
  }

  const qty = Number(addedQty) || 0;
  ingredient.stockIn = (ingredient.stockIn != null ? ingredient.stockIn : ingredient.quantity) + qty;
  ingredient.quantity = (ingredient.stockIn || 0) - (ingredient.totalUsed || 0);
  await ingredient.save();
  return ingredient;
};

const logUsage = async (userId, ingredientId, { dayOfMonth, amount, isOverwrite = false, isAdmin = false, reason = '', updatedBy = {} }) => {
  const ingredient = await Ingredient.findOne({ _id: ingredientId, userId });
  if (!ingredient) {
    throw new AppError('Ingredient not found', 404);
  }

  const usedQty = Number(amount) || 0;
  const dayKey = String(dayOfMonth || new Date().getDate());

  const logs = { ...(ingredient.dailyUsageLogs || {}) };
  const prevVal = Number(logs[dayKey]) || 0;

  // Past & future dates lock: Non-admins can ONLY enter/edit the current running date (today)!
  const todayDate = new Date().getDate();
  if (!isAdmin && Number(dayKey) !== todayDate) {
    throw new AppError(
      `Aap sirf aaj ki tareekh (${todayDate}) mein entry kar saktay hain. Pichli tareekhein sirf Admin edit kar sakta hai.`,
      403
    );
  }

  const shiftLogs = { ...(ingredient.shiftUsageLogs || {}) };
  const dayShiftEntries = Array.isArray(shiftLogs[dayKey]) ? [...shiftLogs[dayKey]] : [];

  const staffUserId = updatedBy.id ? updatedBy.id.toString() : null;
  const staffUserEmail = updatedBy.email ? updatedBy.email.toLowerCase().trim() : null;

  // Check if this specific staff user has ALREADY entered data for this day
  const existingShiftEntryIndex = dayShiftEntries.findIndex((e) => {
    if (staffUserId && e.userId && e.userId.toString() === staffUserId) return true;
    if (staffUserEmail && e.userEmail && e.userEmail.toLowerCase().trim() === staffUserEmail) return true;
    return false;
  });

  // Once entered by this staff user, they CANNOT edit/overwrite! Only Admin can update existing entries!
  if (!isAdmin && existingShiftEntryIndex !== -1) {
    const prevStaffVal = dayShiftEntries[existingShiftEntryIndex].amount;
    throw new AppError(
      `Aap Day ${dayKey} ka data pehle se enter kar chuke hain (${prevStaffVal} ${ingredient.unit}). Is ko ab sirf Admin hi update kar sakta hai.`,
      403
    );
  }

  let newVal = prevVal;

  if (isAdmin) {
    // If Admin is updating the day total directly
    newVal = isOverwrite ? usedQty : (prevVal + usedQty);

    const isEditingExisting = prevVal > 0;
    if (isEditingExisting) {
      if (!reason || !reason.trim()) {
        throw new AppError('Day data update karne ke liye Reason (wajah) enter karna lazmi hai.', 400);
      }
      const edits = { ...(ingredient.dailyUsageEdits || {}) };
      edits[dayKey] = {
        isEdited: true,
        reason: reason.trim(),
        previousAmount: prevVal,
        newAmount: newVal,
        editedByName: updatedBy.name || 'Admin',
        editedByEmail: updatedBy.email || '',
        editedAt: new Date(),
      };
      ingredient.dailyUsageEdits = edits;
      ingredient.markModified('dailyUsageEdits');
    }
  } else {
    // Staff user entering their shift usage
    const staffShiftType = updatedBy.shiftType || 'morning';
    const staffShiftLabel = updatedBy.shiftLabel || (staffShiftType === 'evening' ? 'Evening Shift' : 'Morning Shift');

    const newShiftEntry = {
      userId: staffUserId,
      userName: updatedBy.name || 'Staff User',
      userEmail: staffUserEmail || '',
      shiftType: staffShiftType,
      shiftLabel: staffShiftLabel,
      amount: usedQty,
      enteredAt: new Date().toISOString(),
    };

    dayShiftEntries.push(newShiftEntry);
    shiftLogs[dayKey] = dayShiftEntries;
    ingredient.shiftUsageLogs = shiftLogs;
    ingredient.markModified('shiftUsageLogs');

    // Recalculate day total from all recorded shift entries
    newVal = dayShiftEntries.reduce((sum, e) => sum + (Number(e.amount) || 0), 0);
  }

  const diff = newVal - prevVal;

  logs[dayKey] = newVal;
  ingredient.dailyUsageLogs = logs;
  ingredient.markModified('dailyUsageLogs');

  // Increment total used & recalculate balance
  ingredient.totalUsed = (Number(ingredient.totalUsed) || 0) + diff;
  ingredient.quantity = (ingredient.stockIn != null ? ingredient.stockIn : ingredient.quantity) - ingredient.totalUsed;

  // If low stock or depleted, ensure on shopping list
  if (ingredient.quantity <= (ingredient.lowStockThreshold || 3)) {
    await checkAndAddToShoppingList(userId, ingredient.name);
  }

  await ingredient.save();
  return ingredient;
};

const updateIngredient = async (userId, ingredientId, updateData) => {
  const ingredient = await Ingredient.findOne({ _id: ingredientId, userId });
  if (!ingredient) {
    throw new AppError('Ingredient not found', 404);
  }

  // Check if quantity is set to 0 for auto-adding to shopping list
  if (updateData.quantity === 0 || updateData.quantity === '0') {
    await checkAndAddToShoppingList(userId, ingredient.name);
  }

  Object.assign(ingredient, updateData);
  await ingredient.save();
  return ingredient;
};

const deleteIngredient = async (userId, ingredientId) => {
  const ingredient = await Ingredient.findOneAndDelete({ _id: ingredientId, userId });
  if (!ingredient) {
    throw new AppError('Ingredient not found', 404);
  }

  // Auto add to shopping list on delete
  await checkAndAddToShoppingList(userId, ingredient.name);
  return ingredient;
};

const clearMonthDays = async (userId) => {
  const ingredients = await Ingredient.find({ userId });
  for (const item of ingredients) {
    item.dailyUsageLogs = {};
    item.markModified('dailyUsageLogs');
    item.dailyUsageEdits = {};
    item.markModified('dailyUsageEdits');
    item.shiftUsageLogs = {};
    item.markModified('shiftUsageLogs');
    item.totalUsed = 0;
    item.quantity = item.stockIn != null ? item.stockIn : item.quantity;
    await item.save();
  }
  return ingredients;
};

const closeMonth = async (userId, { monthYear, force = false } = {}) => {
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth(); // 0-indexed
  const lastDayOfMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
  const isMonthCompleted = now.getDate() >= lastDayOfMonth;

  if (!isMonthCompleted && !force) {
    const remainingDays = lastDayOfMonth - now.getDate();
    throw new AppError(
      `Mahina abhi khatam nahi hua! Aaj ${now.getDate()} tarikh hai aur yeh mahina ${lastDayOfMonth} tarikh ko khatam hoga (${remainingDays} din baqi hain).`,
      400
    );
  }

  const resolvedMonthYear = (monthYear && monthYear.trim().length > 0)
    ? monthYear.trim()
    : now.toLocaleString('en-US', { month: 'long', year: 'numeric' });

  const ingredients = await Ingredient.find({ userId });

  let totalStockIn = 0;
  let totalUsed = 0;
  let inHandBalance = 0;

  const snapshotItems = ingredients.map((item) => {
    const sIn = item.stockIn != null ? item.stockIn : item.quantity;
    const used = item.totalUsed || 0;
    const bal = sIn - used;
    const shoppingNeeded = Math.max(0, used - bal);

    totalStockIn += sIn;
    totalUsed += used;
    inHandBalance += bal;

    return {
      name: item.name,
      category: item.category,
      unit: item.unit,
      stockIn: sIn,
      dailyUsageLogs: item.dailyUsageLogs || {},
      dailyUsageEdits: item.dailyUsageEdits || {},
      shiftUsageLogs: item.shiftUsageLogs || {},
      totalUsed: used,
      balance: bal,
      shoppingNeededQty: shoppingNeeded,
    };
  });

  // 1. Create Archive record
  const archive = await MonthlyArchive.create({
    userId,
    monthYear: resolvedMonthYear,
    items: snapshotItems,
    totalStockIn,
    totalUsed,
    inHandBalance,
    closedAt: new Date(),
  });

  // 2. Rollover: closing balance becomes new opening stockIn!
  for (const item of ingredients) {
    const endingBalance = (item.stockIn != null ? item.stockIn : item.quantity) - (item.totalUsed || 0);
    item.stockIn = endingBalance;
    item.quantity = endingBalance;
    item.dailyUsageLogs = {};
    item.markModified('dailyUsageLogs');
    item.dailyUsageEdits = {};
    item.markModified('dailyUsageEdits');
    item.shiftUsageLogs = {};
    item.markModified('shiftUsageLogs');
    item.totalUsed = 0;
    await item.save();
  }

  return { archive, newIngredients: ingredients };
};

const getMonthlyArchives = async (userId) => {
  return await MonthlyArchive.find({ userId }).sort({ closedAt: -1 });
};

const deleteMonthlyArchive = async (userId, archiveId) => {
  const archive = await MonthlyArchive.findOneAndDelete({ _id: archiveId, userId });
  if (!archive) {
    throw new AppError('Archived monthly statement not found', 404);
  }
  return archive;
};

// Helper for auto-depletion logic
const checkAndAddToShoppingList = async (userId, ingredientName) => {
  const existingItem = await ShoppingListItem.findOne({
    userId,
    ingredientName,
    resolved: false,
  });

  if (!existingItem) {
    await ShoppingListItem.create({
      userId,
      ingredientName,
      quantityNeeded: 1, // Defaulting to 1, user can edit later
      addedReason: 'auto-depleted',
    });
  }
};

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
