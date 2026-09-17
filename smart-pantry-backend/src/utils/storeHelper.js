const User = require('../models/User');

let cachedAdminId = null;

const getStoreOwnerId = async (user) => {
  if (!user) return null;
  if (user.role === 'admin') {
    return user._id;
  }
  if (user.createdBy) {
    return user.createdBy;
  }
  if (cachedAdminId) {
    return cachedAdminId;
  }
  const primaryAdmin = await User.findOne({ role: 'admin' }).sort({ createdAt: 1 });
  if (primaryAdmin) {
    cachedAdminId = primaryAdmin._id;
    return primaryAdmin._id;
  }
  return user._id;
};

const canUserEdit = (user) => {
  if (!user) return false;
  if (user.role === 'admin') return true;
  return user.accessMode === 'can_edit';
};

const isUserWithinShift = (user) => {
  if (!user) return false;
  if (user.role === 'admin') return true;
  if (!user.shiftType || user.shiftType === 'all_day') return true;

  const startTime = user.shiftStartTime || (user.shiftType === 'morning' ? '06:00' : '16:00');
  const endTime = user.shiftEndTime || (user.shiftType === 'morning' ? '16:00' : '23:59');

  const now = new Date();
  const currentMinutes = now.getHours() * 60 + now.getMinutes();

  const [startH, startM] = startTime.split(':').map(Number);
  const [endH, endM] = endTime.split(':').map(Number);
  const startMinutes = (startH || 0) * 60 + (startM || 0);
  const endMinutes = (endH || 0) * 60 + (endM || 0);

  if (startMinutes <= endMinutes) {
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  } else {
    // Overnight window (e.g. 20:00 to 04:00)
    return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
  }
};

const getShiftDisplay = (user) => {
  if (!user || user.role === 'admin' || !user.shiftType || user.shiftType === 'all_day') {
    return '24 Hours (Anytime)';
  }
  const start = user.shiftStartTime || (user.shiftType === 'morning' ? '06:00' : '16:00');
  const end = user.shiftEndTime || (user.shiftType === 'morning' ? '16:00' : '23:59');
  const name = user.shiftType === 'morning' ? 'Morning Shift' : (user.shiftType === 'evening' ? 'Evening Shift' : 'Custom Shift');
  return `${name} (${start} - ${end})`;
};

module.exports = {
  getStoreOwnerId,
  canUserEdit,
  isUserWithinShift,
  getShiftDisplay,
};
