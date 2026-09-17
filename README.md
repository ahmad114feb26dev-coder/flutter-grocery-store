# 🛒 Smart Pantry & Grocery Store Management System

A full-stack application for managing grocery store and pantry inventory, office expenses, user roles, recipe tracking, and automated stock alerts.

---

## 📁 Project Structure

```text
flutter-grocery-store/
├── smart_pantry_app/       # Flutter Frontend (Mobile, Web & Desktop)
│   ├── lib/
│   │   ├── core/           # Constants, networking, theme, utilities
│   │   └── features/       # Admin, Auth, Home, Inventory, Notifications, Recipes
│   ├── pubspec.yaml
│   └── web/
└── smart-pantry-backend/   # Node.js + Express + MongoDB REST API
    ├── src/
    │   ├── config/         # Database and server config
    │   ├── controllers/    # API business logic
    │   ├── middleware/     # Auth and error handling
    │   ├── models/         # Mongoose models
    │   └── routes/         # Express API routes
    ├── package.json
    └── server.js
```

---

## 🚀 Features

- **Inventory Tracking:** Manage ingredients and grocery items with real-time stock levels, expiry date alerts, and unit management.
- **Categorization & Filters:** View items by status (Expiring Soon, Fresh, Out of Stock) and category.
- **Office Expense Tracking:** Record daily and monthly office/store operational expenses with visual charts.
- **Recipe Management:** Track pantry recipes with dynamic ingredient deduction.
- **Role-Based Access Control:** Secure JWT authentication with Admin and User management.
- **Interactive UI:** Built with Flutter, modern animations, clean card layouts, and responsive design.

---

## 🛠️ Getting Started

### 1. Backend Setup (`smart-pantry-backend`)

1. Navigate to the backend directory:
   ```bash
   cd smart-pantry-backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create your `.env` file based on `.env.example`:
   ```env
   PORT=5001
   MONGODB_URI=mongodb://127.0.0.1:27017/smart_pantry
   JWT_ACCESS_SECRET=your_jwt_access_secret
   JWT_REFRESH_SECRET=your_jwt_refresh_secret
   JWT_ACCESS_EXPIRES_IN=7d
   JWT_REFRESH_EXPIRES_IN=7d
   ```
4. Start the backend server:
   ```bash
   npm run dev
   # or
   node server.js
   ```

### 2. Frontend Setup (`smart_pantry_app`)

1. Navigate to the Flutter app directory:
   ```bash
   cd smart_pantry_app
   ```
2. Get Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   # Run on Chrome/Web
   flutter run -d chrome

   # Run on connected Android / iOS device
   flutter run
   ```

---

## 👥 Author

- GitHub: [@ahmad114feb26dev-coder](https://github.com/ahmad114feb26dev-coder)
