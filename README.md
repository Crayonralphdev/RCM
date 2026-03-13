# Retro Clurix Miners — Full Stack Setup Guide

## File Structure

```
/                          ← web root
├── .htaccess
├── signin.html
├── register.html
├── dashboard.html
├── admin.html
├── schema.sql
├── seed.sql
│
├── config/
│   └── db.php             ← ⚠️ Set your DB credentials here
│
├── includes/
│   └── helpers.php        ← Shared PHP functions
│
├── mail/
│   └── Mailer.php         ← Email class (PHPMailer or mail() fallback)
│
└── api/
    ├── login.php
    ├── register.php
    ├── verify-otp.php
    ├── forgot-password.php
    ├── verify-reset-otp.php
    ├── reset-password.php
    ├── logout.php
    ├── dashboard.php      ← Dashboard data + actions
    └── admin.php          ← Admin CRUD + finance actions
```

---

## Quick Start

### 1. Database
```sql
-- Run in MySQL / phpMyAdmin:
SOURCE schema.sql;
SOURCE seed.sql;
```

### 2. Config — config/db.php
Update:
```php
define('DB_USER',     'your_db_user');
define('DB_PASS',     'your_db_password');
define('APP_URL',     'https://yourdomain.com');
define('APP_SECRET',  'change_to_32+_random_chars');
define('SMTP_HOST',   'smtp.sendgrid.net');
define('SMTP_USER',   'apikey');
define('SMTP_PASS',   'YOUR_SENDGRID_KEY');
define('MAIL_FROM',   'noreply@yourdomain.com');
```

### 3. PHPMailer (optional but recommended)
```bash
composer require phpmailer/phpmailer
```
Without it, the system falls back to PHP's native `mail()`.

### 4. Upload to server
Place all files in your web root. The `.htaccess` handles HTTPS redirect and security headers.

---

## Default Login Credentials (seed.sql)

| Role  | Email                              | Password    |
|-------|------------------------------------|-------------|
| Admin | admin@retroclurixminers.net        | Demo1234!   |
| User  | demo@retroclurixminers.net         | Demo1234!   |
| User  | trader@example.com                 | Demo1234!   |

> ⚠️ Change all passwords immediately after setup.

---

## Admin Panel

Access `admin.html` — the admin panel reads from the same database via `/api/admin.php`.

**Admin features:**
- Overview stats (users, deposits, withdrawals, messages)
- Real-time notifications from dashboard activity
- User management (add, edit, delete, view profile)
- Set user balances (set / add / subtract, with change log)
- Approve/reject deposits
- Process/reject withdrawal requests
- Read support messages

All admin actions require a valid `role=admin` session.

---

## API Endpoints

| Method | Endpoint                          | Auth     | Description              |
|--------|-----------------------------------|----------|--------------------------|
| POST   | /api/login.php                    | None     | Sign in                  |
| POST   | /api/register.php                 | None     | Create account           |
| POST   | /api/verify-otp.php               | None     | Verify email OTP         |
| POST   | /api/forgot-password.php          | None     | Request reset OTP        |
| POST   | /api/verify-reset-otp.php         | None     | Verify reset OTP         |
| POST   | /api/reset-password.php           | None     | Set new password         |
| POST   | /api/logout.php                   | Bearer   | Invalidate session       |
| GET    | /api/dashboard.php                | Bearer   | Load all dashboard data  |
| POST   | /api/dashboard.php?action=deposit_intent | Bearer | Notify admin of amount |
| POST   | /api/dashboard.php?action=deposit_submit | Bearer | Submit deposit         |
| POST   | /api/dashboard.php?action=withdraw       | Bearer | Request withdrawal     |
| POST   | /api/dashboard.php?action=message        | Bearer | Send support message   |
| POST   | /api/dashboard.php?action=update_profile | Bearer | Update profile         |
| POST   | /api/dashboard.php?action=change_password| Bearer | Change password        |
| GET    | /api/admin.php?action=stats       | Admin    | Overview stats           |
| GET    | /api/admin.php?action=users       | Admin    | List users               |
| GET    | /api/admin.php?action=user&id=N   | Admin    | Single user profile      |
| GET    | /api/admin.php?action=notifications| Admin   | Activity feed            |
| GET    | /api/admin.php?action=deposits    | Admin    | Pending deposits         |
| GET    | /api/admin.php?action=withdrawals | Admin    | Pending withdrawals      |
| GET    | /api/admin.php?action=messages    | Admin    | Support messages         |
| POST   | /api/admin.php?action=set_balance | Admin    | Set user balance         |
| POST   | /api/admin.php?action=approve_deposit    | Admin | Approve + credit deposit |
| POST   | /api/admin.php?action=process_withdrawal | Admin | Approve/reject withdrawal|
| POST   | /api/admin.php?action=update_user | Admin    | Edit user fields         |
| POST   | /api/admin.php?action=delete_user | Admin    | Delete user              |

---

## Email Flow

1. **Register** → OTP sent → verify-otp.php → account active → welcome email
2. **Login** → session token → login alert email
3. **Deposit intent** → admin notified by email (craralph@gmail.com)
4. **Deposit submit** → admin email + DB transaction created (pending)
5. **Admin approves** → balance credited + confirmation email to user
6. **Withdrawal** → admin email + balance locked (pending)
7. **Admin processes** → balance debited (approved) or lock released (rejected)
8. **Support message** → admin email + stored in audit_log

---

## Demo / Offline Mode

All HTML pages detect `localhost` / `file://` and enter demo mode automatically — no PHP server needed. All actions work via localStorage with mock data.
