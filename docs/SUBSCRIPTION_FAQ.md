# Subscription FAQ — Final Evolution Lab

> User-facing FAQ for the $6/week subscription model with 72-hour free trial.

---

## Trial

### How does the free trial work?
When you first download Final Evolution Lab, you automatically get **72 hours (3 days)** of full access to everything:
- All 17 game modes
- All 23 exercise demonstrations
- All 5 workout programs
- Custom workout builder
- Creator challenges and content
- Progress tracking and personal records

**No credit card is required to start your trial.**

### When does my trial start?
Your trial begins the moment you open the app for the first time and complete the onboarding flow.

### Can I see how much trial time I have left?
Yes! A persistent banner at the top of the screen shows your remaining trial time. You'll also receive notifications at 24 hours and 1 hour remaining.

### What happens when my trial ends?
After 72 hours, you'll be prompted to subscribe. If you don't subscribe:
- You won't be able to access game modes
- Workout programs will be locked
- Exercise library will be restricted
- Your progress data is **saved** and will be there when you return

---

## Subscription

### How much does it cost?
**$6 per week**, billed weekly.

That's less than a single sports drink. For the price of one energy bar per week, you get access to a complete sports training platform.

### What payment methods do you accept?
- **Credit / Debit cards** (Visa, Mastercard, Amex, Discover) via Stripe
- **Apple Pay** (on iOS)
- **Google Pay** (on Android/Web)

### Can I cancel anytime?
Absolutely. Cancel from your account settings at any time. No cancellation fees, no hidden charges.

### What happens when I cancel?
You'll retain access until the end of your current billing period. After that, you'll lose access to premium features but your progress is always saved.

### Is there an annual plan?
Not yet, but we're considering it. Stay tuned!

---

## Billing

### When am I charged?
You're charged $6 every 7 days from the date you subscribe.

### What if my payment fails?
We'll retry the payment automatically. You'll have a **24-hour grace period** during which you can update your payment method. After 3 failed attempts, your subscription will be suspended.

### How do I update my payment method?
1. Open Final Evolution Lab
2. Go to Settings → Subscription
3. Tap "Manage Subscription"
4. Update your payment method

### Can I get a refund?
We offer refunds for the most recent billing cycle if requested within 48 hours of being charged. Contact support@finalevolutiongroup.com.

---

## What's Included

### Free Trial (72 hours)
✅ Full access to everything listed below — no restrictions.

### Subscription ($6/week)
✅ **17 Game Modes** — Basketball, Soccer, Karate, Tennis, Golf, Baseball, Volleyball, Boxing, Swimming, Surfing, Gymnastics, Skating, Football, Dunk Contest, and more

✅ **23 Animated Exercises** — 3D demonstrations with form checkpoints for warm-up, strength, mobility, sport-specific, and recovery exercises

✅ **5 Workout Programs** — Basketball Performance (8wk), Strength Foundation (12wk), Athletic Conditioning (6wk), Mobility & Recovery (4wk), Dunk Training (10wk)

✅ **Custom Workout Builder** — Create your own programs with any combination of exercises

✅ **Progressive Overload** — Automatic progression with linear, undulating, and block periodization

✅ **Creator Challenges** — Train with pro athletes like Elijah Bonds

✅ **Progress Tracking** — Calories burned, personal records, completion history

✅ **Pixel Streaming** — Console-quality UE5 graphics on any device

---

## Technical

### Subscription System Architecture
- **Payment Processing:** Stripe (Web/iOS/Android)
- **Trial Tracking:** Local device + server verification
- **Access Control:** Real-time subscription status check before game mode launch
- **Billing Portal:** https://billing.finalevolutiongroup.com/portal

### API Endpoints
| Endpoint | Purpose |
|----------|---------|
| `POST /v1/subscription/create-checkout` | Create Stripe checkout session |
| `POST /v1/subscription/update-payment` | Update payment method |
| `POST /v1/subscription/cancel` | Cancel subscription |
| `POST /v1/subscription/restore` | Restore from receipt |
| `POST /v1/subscription/webhook` | Stripe webhook handler |

---

## Contact

**Support:** support@finalevolutiongroup.com  
**Website:** https://finalevolutiongroup.com  
**Billing Portal:** https://billing.finalevolutiongroup.com/portal
