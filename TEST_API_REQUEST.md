# Testing the API Request

## Current Implementation

Our app sends:
```json
{
  "phone": "9999999999",
  "otp": "123456",
  "termsAccepted": true
}
```

## Possible Backend Variations

The backend might expect one of these field names:
- `termsAccepted` (camelCase)
- `terms_accepted` (snake_case)
- `acceptedTerms` (different camelCase)
- `accepted_terms` (different snake_case)
- `acceptTerms` (different)
- `terms` (short)

## How to Check

1. **Look at your backend validation code** and share the exact field name it checks
2. **Check the API documentation** for the exact field name
3. **Test with Postman/curl** to see what works:

```bash
curl -X POST https://api.hireforcare.com/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "9999999999",
    "otp": "123456",
    "termsAccepted": true
  }'
```

## Quick Fix Options

If backend expects different field name, we can change it in `lib/services/api_service.dart` line 104.

**Please share:**
1. Your backend validation code
2. The exact error response from backend (full JSON)
