const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    passwordHash: {
      type: String,
      required: true,
    },
    refreshTokenHash: {
      type: String,
      default: null,
    },
    role: {
      type: String,
      enum: ['admin', 'user'],
      default: 'admin',
    },
    allowedSections: {
      type: [String],
      default: ['dashboard', 'pantry', 'expenses', 'reports', 'shopping_list'],
    },
    accessMode: {
      type: String,
      enum: ['view_only', 'can_edit'],
      default: 'view_only',
    },
    shiftType: {
      type: String,
      enum: ['all_day', 'morning', 'evening', 'custom'],
      default: 'all_day',
    },
    shiftStartTime: {
      type: String,
      default: null, // e.g. "06:00"
    },
    shiftEndTime: {
      type: String,
      default: null, // e.g. "16:00"
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', userSchema);
