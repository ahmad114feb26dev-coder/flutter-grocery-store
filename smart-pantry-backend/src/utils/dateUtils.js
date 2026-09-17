/**
 * Calculates the number of days left until expiry.
 * Negative number means it's already expired.
 */
const calculateDaysLeft = (expiryDate) => {
  if (!expiryDate) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0); // Normalize to start of day

  const expiry = new Date(expiryDate);
  expiry.setHours(0, 0, 0, 0);

  const diffTime = expiry - today;
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  return diffDays;
};

module.exports = { calculateDaysLeft };
